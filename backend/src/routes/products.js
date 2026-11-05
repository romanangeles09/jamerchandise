const express = require("express");
const Product = require("../models/Product");
const { protect } = require("../middleware/auth");
const { applyProductDefaults, saveProductWithSkuRetry } = require("../lib/productDefaults");

const router = express.Router();

function optionalNumber(value) {
  if (value === undefined || value === null || String(value).trim() === "") return null;
  const amount = Number(value);
  return Number.isNaN(amount) ? null : amount;
}

function productPayload(body) {
  const wholesalePrice = optionalNumber(body.wholesalePrice);
  const wholesaleMinQty = optionalNumber(body.wholesaleMinQty);
  return {
    name: String(body.name || "").trim(),
    alias: String(body.alias || "").trim(),
    sku: String(body.sku || "").trim().toUpperCase(),
    barcode: String(body.barcode || "").trim(),
    category: body.category,
    unit: String(body.unit || "pc").trim() || "pc",
    retailPrice: Number(body.retailPrice),
    wholesalePrice,
    wholesaleMinQty: wholesalePrice != null && wholesaleMinQty == null ? 1 : wholesaleMinQty,
    costPrice: optionalNumber(body.costPrice),
    stock: Number(body.stock || 0),
    reorderLevel: Number(body.reorderLevel || 10),
    isActive: body.isActive !== "false" && body.isActive !== false,
  };
}

function validateProduct(data) {
  if (!data.name) return "Product name is required.";
  if (!data.sku) return "SKU is required.";
  if (!data.category) return "Category is required.";
  if (Number.isNaN(data.retailPrice) || data.retailPrice < 0) return "Retail price is invalid.";
  if (data.wholesalePrice != null && data.wholesalePrice < 0) return "Wholesale price is invalid.";
  if (data.wholesaleMinQty != null && data.wholesaleMinQty < 1) return "Wholesale min qty is invalid.";
  if (data.costPrice != null && data.costPrice < 0) return "Cost is invalid.";
  return null;
}

function toProductJson(product) {
  const json = product.toJSON();
  delete json.image;
  delete json.imagePublicId;
  delete json.imageUrl;
  delete json.hasImage;
  return json;
}

const PRODUCT_SELECT = "-image -imageUrl -imagePublicId -hasImage";

router.use(protect);

router.get("/", async (req, res) => {
  try {
    const { q, category, active } = req.query;
    const filter = {};
    if (category) filter.category = category;
    if (active === "true") filter.isActive = true;
    if (q) {
      const term = String(q).trim();
      filter.$or = [
        { name: { $regex: term, $options: "i" } },
        { alias: { $regex: term, $options: "i" } },
        { sku: { $regex: term, $options: "i" } },
        { barcode: { $regex: term, $options: "i" } },
      ];
    }

    const total = await Product.countDocuments(filter);
    const wantAll = req.query.all === "1" || req.query.all === "true";
    const limit = wantAll
      ? Math.max(total, 1)
      : Math.min(Math.max(Number(req.query.limit) || 25, 1), 100);
    const pages = Math.max(1, Math.ceil(total / limit) || 1);
    const page = wantAll ? 1 : Math.min(Math.max(Number(req.query.page) || 1, 1), pages);
    const skip = wantAll ? 0 : (page - 1) * limit;

    const items = await Product.find(filter)
      .select(PRODUCT_SELECT)
      .populate("category", "name")
      .sort({ name: 1 })
      .skip(skip)
      .limit(limit);

    res.json({
      items: items.map(toProductJson),
      total,
      page,
      limit,
      pages,
    });
  } catch (error) {
    res.status(500).json({ message: "Unable to load products." });
  }
});

router.post("/", async (req, res) => {
  try {
    const data = productPayload(req.body);
    data.sku = "";
    await applyProductDefaults(data);
    const error = validateProduct(data);
    if (error) return res.status(400).json({ message: error });

    const product = new Product(data);
    await saveProductWithSkuRetry(product, { regenerateSku: true, regenerateBarcode: true });
    await product.populate("category", "name");
    res.status(201).json(toProductJson(product));
  } catch (error) {
    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern || error.keyValue || {})[0];
      return res.status(400).json({
        message: field === "barcode" ? "A product with that barcode already exists." : "A product with that SKU already exists.",
      });
    }
    res.status(error.status || 500).json({ message: error.message || "Unable to create product." });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const data = productPayload(req.body);
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ message: "Product not found." });

    data.sku = product.sku;
    data.barcode = product.barcode;
    await applyProductDefaults(data, product);
    const error = validateProduct(data);
    if (error) return res.status(400).json({ message: error });

    Object.assign(product, data);
    await saveProductWithSkuRetry(product, { regenerateSku: false });
    await product.populate("category", "name");
    res.json(toProductJson(product));
  } catch (error) {
    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern || error.keyValue || {})[0];
      return res.status(400).json({
        message: field === "barcode" ? "A product with that barcode already exists." : "A product with that SKU already exists.",
      });
    }
    res.status(error.status || 500).json({ message: error.message || "Unable to update product." });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    const product = await Product.findByIdAndDelete(req.params.id);
    if (!product) return res.status(404).json({ message: "Product not found." });
    res.json({ message: "Product deleted." });
  } catch (error) {
    res.status(500).json({ message: "Unable to delete product." });
  }
});

module.exports = router;
