const express = require("express");
const Product = require("../models/Product");
const { protect } = require("../middleware/auth");
const { handleImageUpload } = require("../lib/upload");
const { uploadProductImage, destroyImage } = require("../lib/cloudinary");
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

async function applyImage(product, req) {
  if (req.file) {
    if (product.imagePublicId) await destroyImage(product.imagePublicId);
    const result = await uploadProductImage(req.file);
    product.imageUrl = result.secure_url;
    product.imagePublicId = result.public_id;
    product.hasImage = true;
    product.image = undefined;
    return;
  }
  if (String(req.body.removeImage) === "true") {
    if (product.imagePublicId) await destroyImage(product.imagePublicId);
    product.imageUrl = "";
    product.imagePublicId = "";
    product.hasImage = false;
    product.image = undefined;
  }
}

function toProductJson(product) {
  const json = product.toJSON();
  delete json.image;
  delete json.imagePublicId;
  json.hasImage = Boolean(product.imageUrl || product.hasImage);
  json.imageUrl = product.imageUrl || "";
  return json;
}

router.get("/:id/image", async (req, res) => {
  try {
    const product = await Product.findById(req.params.id).select("image imageUrl hasImage");
    if (product?.imageUrl) {
      return res.redirect(product.imageUrl);
    }
    if (!product?.hasImage || !product.image?.data) {
      return res.status(404).json({ message: "No image for this product." });
    }
    res.set("Content-Type", product.image.contentType || "image/jpeg");
    res.set("Cache-Control", "public, max-age=86400");
    res.send(product.image.data);
  } catch (error) {
    res.status(404).json({ message: "No image for this product." });
  }
});

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
        { sku: { $regex: term, $options: "i" } },
        { barcode: { $regex: term, $options: "i" } },
      ];
    }

    const products = await Product.find(filter)
      .select("-image")
      .populate("category", "name")
      .sort({ name: 1 });
    res.json(products);
  } catch (error) {
    res.status(500).json({ message: "Unable to load products." });
  }
});

router.post("/", handleImageUpload, async (req, res) => {
  try {
    const providedSku = Boolean(String(req.body.sku || "").trim());
    const data = productPayload(req.body);
    await applyProductDefaults(data);
    const error = validateProduct(data);
    if (error) return res.status(400).json({ message: error });

    const product = new Product(data);
    await applyImage(product, req);
    await saveProductWithSkuRetry(product, { regenerateSku: !providedSku });
    await product.populate("category", "name");
    res.status(201).json(toProductJson(product));
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "A product with that SKU already exists." });
    }
    res.status(error.status || 500).json({ message: error.message || "Unable to create product." });
  }
});

router.put("/:id", handleImageUpload, async (req, res) => {
  try {
    const providedSku = Boolean(String(req.body.sku || "").trim());
    const data = productPayload(req.body);
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ message: "Product not found." });

    await applyProductDefaults(data, product);
    const error = validateProduct(data);
    if (error) return res.status(400).json({ message: error });

    Object.assign(product, data);
    await applyImage(product, req);
    await saveProductWithSkuRetry(product, { regenerateSku: !providedSku });
    await product.populate("category", "name");
    res.json(toProductJson(product));
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "A product with that SKU already exists." });
    }
    res.status(error.status || 500).json({ message: error.message || "Unable to update product." });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    const product = await Product.findByIdAndDelete(req.params.id);
    if (!product) return res.status(404).json({ message: "Product not found." });
    if (product.imagePublicId) await destroyImage(product.imagePublicId);
    res.json({ message: "Product deleted." });
  } catch (error) {
    res.status(500).json({ message: "Unable to delete product." });
  }
});

module.exports = router;
