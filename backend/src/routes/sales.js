const express = require("express");
const Product = require("../models/Product");
const Sale = require("../models/Sale");
const { protect } = require("../middleware/auth");
const { ownSalesFilter } = require("../lib/salesScope");

const router = express.Router();
router.use(protect);

async function nextInvoiceNo() {
  const count = await Sale.countDocuments();
  return `JA-${String(count + 1).padStart(6, "0")}`;
}

router.get("/", async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 25, 100);
    const sales = await Sale.find(ownSalesFilter(req.user))
      .populate("cashier", "name")
      .sort({ createdAt: -1 })
      .limit(limit);
    res.json(sales);
  } catch (error) {
    res.status(500).json({ message: "Unable to load sales." });
  }
});

router.post("/", async (req, res) => {
  try {
    const saleType = req.body.saleType === "wholesale" ? "wholesale" : "retail";
    const paymentMethod = ["cash", "gcash"].includes(req.body.paymentMethod)
      ? req.body.paymentMethod
      : "cash";
    const discount = Math.max(0, Number(req.body.discount) || 0);
    const amountPaid = Number(req.body.amountPaid);
    const gcashTxnNo = String(req.body.gcashTxnNo || "").trim();
    const rawItems = Array.isArray(req.body.items) ? req.body.items : [];

    if (!rawItems.length) {
      return res.status(400).json({ message: "Add at least one item to the cart." });
    }
    if (Number.isNaN(amountPaid) || amountPaid < 0) {
      return res.status(400).json({ message: "Amount paid is invalid." });
    }
    if (paymentMethod === "gcash" && !gcashTxnNo) {
      return res.status(400).json({ message: "GCash Txn No. is required." });
    }

    const items = [];
    let subtotal = 0;
    const stockUpdates = [];

    for (const line of rawItems) {
      const qty = Number(line.qty);
      if (!line.product || !Number.isInteger(qty) || qty < 1) {
        return res.status(400).json({ message: "Each cart item needs a valid product and quantity." });
      }

      const product = await Product.findById(line.product);
      if (!product || !product.isActive) {
        return res.status(400).json({ message: "One of the products is no longer available." });
      }
      if (product.stock < qty) {
        return res.status(400).json({ message: `Not enough stock for ${product.name}.` });
      }
      if (saleType === "wholesale") {
        if (!(Number(product.wholesalePrice) > 0)) {
          return res.status(400).json({ message: `${product.name} is not available for wholesale.` });
        }
        const minQty = Number(product.wholesaleMinQty) > 0 ? product.wholesaleMinQty : 1;
        if (qty < minQty) {
          return res.status(400).json({
            message: `${product.name} requires at least ${minQty} ${product.unit} for wholesale.`,
          });
        }
      }

      const unitPrice = saleType === "wholesale" ? product.wholesalePrice : product.retailPrice;
      const lineTotal = Number((unitPrice * qty).toFixed(2));
      subtotal += lineTotal;
      stockUpdates.push({ product, qty });

      items.push({
        product: product._id,
        name: product.name,
        sku: product.sku,
        qty,
        unitPrice,
        lineTotal,
      });
    }

    subtotal = Number(subtotal.toFixed(2));
    if (discount > subtotal) {
      return res.status(400).json({ message: "Discount cannot exceed the subtotal." });
    }

    const total = Number((subtotal - discount).toFixed(2));
    if (amountPaid < total) {
      return res.status(400).json({ message: "Amount paid is less than the total." });
    }

    for (const { product, qty } of stockUpdates) {
      product.stock -= qty;
      await product.save();
    }

    const sale = await Sale.create({
      invoiceNo: await nextInvoiceNo(),
      saleType,
      items,
      subtotal,
      discount,
      total,
      amountPaid,
      change: Number((amountPaid - total).toFixed(2)),
      paymentMethod,
      gcashTxnNo: paymentMethod === "gcash" ? gcashTxnNo : "",
      cashier: req.user._id,
      userId: req.user._id,
    });

    await sale.populate("cashier", "name");
    res.status(201).json(sale);
  } catch (error) {
    res.status(500).json({ message: "Unable to complete this sale." });
  }
});

module.exports = router;
