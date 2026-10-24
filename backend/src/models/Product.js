const mongoose = require("mongoose");

const productSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    sku: { type: String, required: true, unique: true, trim: true, uppercase: true },
    barcode: { type: String, default: "", trim: true },
    category: { type: mongoose.Schema.Types.ObjectId, ref: "Category", required: true },
    unit: { type: String, default: "pc" },
    retailPrice: { type: Number, required: true, min: 0 },
    wholesalePrice: { type: Number, required: true, min: 0 },
    wholesaleMinQty: { type: Number, default: 6, min: 1 },
    costPrice: { type: Number, default: 0, min: 0 },
    stock: { type: Number, default: 0, min: 0 },
    reorderLevel: { type: Number, default: 10, min: 0 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

productSchema.index({ name: "text", sku: "text", barcode: "text" });

module.exports = mongoose.model("Product", productSchema);
