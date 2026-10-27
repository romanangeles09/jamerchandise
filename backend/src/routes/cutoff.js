const express = require("express");
const mongoose = require("mongoose");
const Sale = require("../models/Sale");
const User = require("../models/User");
const { protect, requireAccess } = require("../middleware/auth");

const router = express.Router();
router.use(protect, requireAccess("cutoff"));

function manilaDayRange(dateKey) {
  const key = /^\d{4}-\d{2}-\d{2}$/.test(dateKey)
    ? dateKey
    : new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Manila" }).format(new Date());
  return {
    key,
    start: new Date(`${key}T00:00:00+08:00`),
    end: new Date(`${key}T23:59:59.999+08:00`),
  };
}

router.get("/", async (req, res) => {
  try {
    const { key, start, end } = manilaDayRange(String(req.query.date || ""));
    const payment = ["cash", "gcash"].includes(req.query.payment) ? req.query.payment : "all";
    const canPickCashier = ["SuperAdmin", "Admin"].includes(req.user.role);

    let cashierId = String(req.user._id);
    if (canPickCashier && req.query.cashier) {
      cashierId = req.query.cashier === "all" ? "" : String(req.query.cashier);
    }

    const match = { createdAt: { $gte: start, $lte: end } };
    if (cashierId && mongoose.Types.ObjectId.isValid(cashierId)) {
      const id = new mongoose.Types.ObjectId(cashierId);
      match.$or = [{ cashier: id }, { userId: id }];
    }
    if (payment !== "all") match.paymentMethod = payment;

    const sales = await Sale.find(match).populate("cashier", "name email").sort({ createdAt: 1 });

    const productsMap = new Map();
    let tickets = 0;
    let itemCount = 0;
    let subtotal = 0;
    let discount = 0;
    let total = 0;
    let cash = 0;
    let gcash = 0;

    for (const sale of sales) {
      tickets += 1;
      subtotal += sale.subtotal;
      discount += sale.discount;
      total += sale.total;
      if (sale.paymentMethod === "gcash") gcash += sale.total;
      if (sale.paymentMethod === "cash") cash += sale.total;

      for (const item of sale.items) {
        itemCount += item.qty;
        const current = productsMap.get(item.sku) || {
          sku: item.sku,
          name: item.name,
          qty: 0,
          amount: 0,
        };
        current.qty += item.qty;
        current.amount += item.lineTotal;
        productsMap.set(item.sku, current);
      }
    }

    const cashiers = canPickCashier
      ? await User.find({ isActive: { $ne: false } }).select("name email role").sort({ name: 1 })
      : [];

    res.json({
      date: key,
      payment,
      cashierId: cashierId || "all",
      canPickCashier,
      cashiers: cashiers.map((user) => ({
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      })),
      summary: {
        tickets,
        itemCount,
        subtotal: Number(subtotal.toFixed(2)),
        discount: Number(discount.toFixed(2)),
        total: Number(total.toFixed(2)),
        cash: Number(cash.toFixed(2)),
        gcash: Number(gcash.toFixed(2)),
      },
      products: [...productsMap.values()].sort((a, b) => b.amount - a.amount),
      sales,
    });
  } catch (error) {
    res.status(500).json({ message: "Unable to load cutoff." });
  }
});

module.exports = router;
