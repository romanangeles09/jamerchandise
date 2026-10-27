require("dotenv").config();
const mongoose = require("mongoose");
const connectDb = require("../config/db");
const User = require("../models/User");
const Category = require("../models/Category");
const Product = require("../models/Product");

const categories = [
  { name: "Apparel", description: "Shirts, uniforms, and bulk clothing packs" },
  { name: "Accessories", description: "Bags, caps, and everyday carry items" },
  { name: "Home Goods", description: "Household staples sold retail and by the case" },
  { name: "Personal Care", description: "Toiletries and hygiene packs" },
  { name: "Stationery", description: "Office and school supplies" },
];

const products = [
  ["Cotton Crew Shirt", "APP-001", "Apparel", "pc", 249, 189, 6, 120, 140],
  ["Collared Polo Shirt", "APP-002", "Apparel", "pc", 349, 269, 6, 180, 90],
  ["Unisex Hoodie", "APP-003", "Apparel", "pc", 799, 620, 4, 420, 40],
  ["Canvas Tote Bag", "ACC-001", "Accessories", "pc", 199, 145, 10, 80, 150],
  ["Adjustable Cap", "ACC-002", "Accessories", "pc", 179, 129, 12, 70, 80],
  ["Travel Pouch Set", "ACC-003", "Accessories", "set", 259, 190, 6, 110, 55],
  ["Microfiber Towel", "HOM-001", "Home Goods", "pc", 129, 89, 12, 45, 200],
  ["Storage Basket", "HOM-002", "Home Goods", "pc", 299, 220, 6, 130, 70],
  ["Kitchen Cloth Pack", "HOM-003", "Home Goods", "pack", 159, 110, 8, 60, 95],
  ["Hand Soap 500ml", "PER-001", "Personal Care", "bottle", 89, 62, 12, 35, 180],
  ["Body Wash 1L", "PER-002", "Personal Care", "bottle", 149, 105, 8, 70, 110],
  ["Face Towel 3-Pack", "PER-003", "Personal Care", "pack", 119, 85, 10, 48, 75],
  ["Ballpen Box of 12", "STA-001", "Stationery", "box", 96, 68, 10, 40, 130],
  ["A4 Notebook", "STA-002", "Stationery", "pc", 45, 28, 24, 18, 220],
  ["Stapler Heavy Duty", "STA-003", "Stationery", "pc", 189, 140, 6, 85, 40],
];

async function seed() {
  await connectDb();

  const email = "jabulakan@gmail.com";
  const existingAdmin = await User.findOne({ email });
  if (!existingAdmin) {
    await User.create({
      name: "JA Super Admin",
      email,
      password: "SuperAdmin",
      role: "SuperAdmin",
      access: ["dashboard", "transactions", "pos", "cutoff", "inventory", "users", "account"],
    });
    console.log("Seeded SuperAdmin: jabulakan@gmail.com / SuperAdmin");
  } else {
    existingAdmin.role = "SuperAdmin";
    existingAdmin.access = ["dashboard", "transactions", "pos", "cutoff", "inventory", "users", "account"];
    await existingAdmin.save();
    console.log("SuperAdmin already exists.");
  }

  const categoryDocs = {};
  for (const category of categories) {
    const doc = await Category.findOneAndUpdate(
      { name: category.name },
      category,
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    categoryDocs[category.name] = doc._id;
  }

  for (const [name, sku, categoryName, unit, retailPrice, wholesalePrice, wholesaleMinQty, costPrice, stock] of products) {
    await Product.findOneAndUpdate(
      { sku },
      {
        name,
        sku,
        barcode: sku.replace("-", ""),
        category: categoryDocs[categoryName],
        unit,
        retailPrice,
        wholesalePrice,
        wholesaleMinQty,
        costPrice,
        stock,
        reorderLevel: Math.max(8, Math.round(stock * 0.15)),
        isActive: true,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
  }

  console.log("Seeded categories and sample merchandise.");
  await mongoose.disconnect();
}

seed().catch((error) => {
  console.error(error);
  process.exit(1);
});
