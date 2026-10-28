const Category = require("../models/Category");
const Product = require("../models/Product");

function skuPrefix(categoryName) {
  const word = String(categoryName || "").trim().split(/\s+/)[0] || "PRD";
  const letters = word.replace(/[^A-Za-z0-9]/g, "").slice(0, 3).toUpperCase();
  const base = letters || "PRD";
  return base.length >= 3 ? base.slice(0, 3) : base.padEnd(3, "X");
}

function derivedCostPrice(wholesalePrice, wholesaleMinQty) {
  if (wholesalePrice == null) return null;
  const qty = wholesaleMinQty == null ? 1 : Number(wholesaleMinQty);
  if (!Number.isFinite(qty) || qty < 1) return null;
  return Number((Number(wholesalePrice) * qty).toFixed(2));
}

async function nextSkuForCategory(categoryId) {
  const category = await Category.findById(categoryId).select("name");
  if (!category) {
    const error = new Error("Category is required.");
    error.status = 400;
    throw error;
  }

  const prefix = skuPrefix(category.name);
  const escaped = prefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const products = await Product.find({ sku: new RegExp(`^${escaped}-\\d+$`, "i") })
    .select("sku")
    .lean();

  let max = 0;
  for (const product of products) {
    const n = Number(String(product.sku).split("-").pop());
    if (Number.isInteger(n) && n > max) max = n;
  }

  return `${prefix}-${String(max + 1).padStart(3, "0")}`;
}

async function applyProductDefaults(data, existing) {
  if (!data.sku) {
    if (existing?.sku) data.sku = existing.sku;
    else if (data.category) data.sku = await nextSkuForCategory(data.category);
  }
  if (data.costPrice == null) {
    data.costPrice = derivedCostPrice(data.wholesalePrice, data.wholesaleMinQty);
  }
  return data;
}

async function saveProductWithSkuRetry(product, { regenerateSku } = {}) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      await product.save();
      return;
    } catch (error) {
      if (error.code !== 11000 || !regenerateSku) throw error;
      product.sku = await nextSkuForCategory(product.category);
    }
  }
  const conflict = new Error("A product with that SKU already exists.");
  conflict.status = 400;
  throw conflict;
}

module.exports = {
  applyProductDefaults,
  derivedCostPrice,
  nextSkuForCategory,
  saveProductWithSkuRetry,
  skuPrefix,
};
