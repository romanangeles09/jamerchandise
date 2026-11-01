const crypto = require("crypto");
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

function generateCode128Value() {
  return `${crypto.randomInt(1, 10)}${Array.from({ length: 12 }, () => crypto.randomInt(0, 10)).join("")}`;
}

async function nextCode128Barcode() {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const code = generateCode128Value();
    const exists = await Product.exists({ barcode: code });
    if (!exists) return code;
  }
  const error = new Error("Unable to generate a unique barcode.");
  error.status = 500;
  throw error;
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
  data.sku = String(data.sku || "").trim().toUpperCase();
  if (!data.barcode) {
    data.barcode = existing?.barcode || (await nextCode128Barcode());
  }
  data.costPrice = derivedCostPrice(data.wholesalePrice, data.wholesaleMinQty);
  return data;
}

function duplicateField(error) {
  return Object.keys(error.keyPattern || error.keyValue || {})[0] || "sku";
}

async function saveProductWithSkuRetry(product, { regenerateSku, regenerateBarcode } = {}) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      await product.save();
      return;
    } catch (error) {
      if (error.code !== 11000) throw error;
      const field = duplicateField(error);
      if (field === "sku" && regenerateSku) {
        product.sku = await nextSkuForCategory(product.category);
        continue;
      }
      if (field === "barcode" && regenerateBarcode) {
        product.barcode = await nextCode128Barcode();
        continue;
      }
      const conflict = new Error(
        field === "barcode" ? "A product with that barcode already exists." : "A product with that SKU already exists."
      );
      conflict.status = 400;
      throw conflict;
    }
  }
  const conflict = new Error("A product with that SKU already exists.");
  conflict.status = 400;
  throw conflict;
}

module.exports = {
  applyProductDefaults,
  derivedCostPrice,
  generateCode128Value,
  nextCode128Barcode,
  nextSkuForCategory,
  saveProductWithSkuRetry,
  skuPrefix,
};
