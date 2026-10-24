const express = require("express");
const Product = require("../models/Product");
const { protect } = require("../middleware/auth");

const router = express.Router();
router.use(protect);

function productPayload(body) {
  return {
    name: String(body.name || "").trim(),
    sku: String(body.sku || "").trim().toUpperCase(),
    barcode: String(body.barcode || "").trim(),
    category: body.category,
    unit: String(body.unit || "pc").trim() || "pc",
    retailPrice: Number(body.retailPrice),
    wholesalePrice: Number(body.wholesalePrice),
    wholesaleMinQty: Number(body.wholesaleMinQty || 6),
    costPrice: Number(body.costPrice || 0),
    stock: Number(body.stock || 0),
    reorderLevel: Number(body.reorderLevel || 10),
    isActive: body.isActive !== false,
  };
}

function validateProduct(data) {
  if (!data.name) return "Product name is required.";
  if (!data.sku) return "SKU is required.";
  if (!data.category) return "Category is required.";
  if (Number.isNaN(data.retailPrice) || data.retailPrice < 0) return "Retail price is invalid.";
  if (Number.isNaN(data.wholesalePrice) || data.wholesalePrice < 0) return "Wholesale price is invalid.";
  return null;
}

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
        { sku: { $regex: term, $options: "i" } },
        { barcode: { $regex: term, $options: "i" } },
      ];
    }

    const products = await Product.find(filter)
      .populate("category", "name")
      .sort({ name: 1 });
    res.json(products);
  } catch (error) {
    res.status(500).json({ message: "Unable to load products." });
  }
});

router.post("/", async (req, res) => {
  try {
    const data = productPayload(req.body);
    const error = validateProduct(data);
    if (error) return res.status(400).json({ message: error });

    const product = await Product.create(data);
    await product.populate("category", "name");
    res.status(201).json(product);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "A product with that SKU already exists." });
    }
    res.status(500).json({ message: "Unable to create product." });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const data = productPayload(req.body);
    const error = validateProduct(data);
    if (error) return res.status(400).json({ message: error });

    const product = await Product.findByIdAndUpdate(req.params.id, data, {
      new: true,
      runValidators: true,
    }).populate("category", "name");
    if (!product) return res.status(404).json({ message: "Product not found." });
    res.json(product);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "A product with that SKU already exists." });
    }
    res.status(500).json({ message: "Unable to update product." });
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
