const mongoose = require("mongoose");

const productSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    sku: { type: String, required: true, unique: true, trim: true, uppercase: true },
    barcode: { type: String, default: "", trim: true },
    category: { type: mongoose.Schema.Types.ObjectId, ref: "Category", required: true },
    unit: { type: String, default: "pc" },
    retailPrice: { type: Number, required: true, min: 0 },
    wholesalePrice: { type: Number, min: 0, default: null },
    wholesaleMinQty: { type: Number, min: 1, default: null },
    costPrice: { type: Number, min: 0, default: null },
    stock: { type: Number, default: 0, min: 0 },
    reorderLevel: { type: Number, default: 10, min: 0 },
    isActive: { type: Boolean, default: true },
    hasImage: { type: Boolean, default: false },
    imageUrl: { type: String, default: "" },
    imagePublicId: { type: String, default: "" },
    image: {
      data: Buffer,
      contentType: String,
    },
  },
  { timestamps: true }
);

productSchema.index({ name: "text", sku: "text", barcode: "text" });

module.exports = mongoose.model("Product", productSchema);
