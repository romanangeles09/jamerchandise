const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const { ACCESS_PAGES } = require("../lib/access");

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true, minlength: 6, select: false },
    pincode: { type: String, select: false },
    role: { type: String, enum: ["SuperAdmin", "Admin", "Cashier"], default: "Cashier" },
    access: { type: [String], enum: ACCESS_PAGES, default: ["pos", "cutoff", "account"] },
    isActive: { type: Boolean, default: true },
    avatarUrl: { type: String, default: "" },
    avatarPublicId: { type: String, default: "" },
  },
  { timestamps: true }
);

userSchema.pre("save", async function hashSecrets(next) {
  if (this.isModified("password") && this.password) {
    this.password = await bcrypt.hash(this.password, 10);
  }
  if (this.isModified("pincode") && this.pincode) {
    this.pincode = await bcrypt.hash(this.pincode, 10);
  }
  next();
});

userSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

userSchema.methods.comparePincode = function comparePincode(candidate) {
  if (!this.pincode) return Promise.resolve(false);
  return bcrypt.compare(candidate, this.pincode);
};

module.exports = mongoose.model("User", userSchema);
