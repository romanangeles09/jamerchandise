const mongoose = require("mongoose");

const saleItemSchema = new mongoose.Schema(
  {
    product: { type: mongoose.Schema.Types.ObjectId, ref: "Product", required: true },
    name: { type: String, required: true },
    sku: { type: String, required: true },
    qty: { type: Number, required: true, min: 1 },
    unitPrice: { type: Number, required: true, min: 0 },
    lineTotal: { type: Number, required: true, min: 0 },
  },
  { _id: false }
);

const saleSchema = new mongoose.Schema(
  {
    invoiceNo: { type: String, required: true, unique: true },
    saleType: { type: String, enum: ["retail", "wholesale"], required: true },
    items: { type: [saleItemSchema], required: true },
    subtotal: { type: Number, required: true, min: 0 },
    discount: { type: Number, default: 0, min: 0 },
    total: { type: Number, required: true, min: 0 },
    amountPaid: { type: Number, required: true, min: 0 },
    change: { type: Number, default: 0, min: 0 },
    paymentMethod: { type: String, enum: ["cash", "gcash", "card"], default: "cash" },
    gcashTxnNo: { type: String, default: "", trim: true },
    cashier: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", index: true },
  },
  { timestamps: true }
);

saleSchema.pre("validate", function setUserId(next) {
  if (!this.userId && this.cashier) this.userId = this.cashier;
  next();
});

module.exports = mongoose.model("Sale", saleSchema);
