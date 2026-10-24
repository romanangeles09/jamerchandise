const express = require("express");
const Category = require("../models/Category");
const Product = require("../models/Product");
const { protect } = require("../middleware/auth");

const router = express.Router();
router.use(protect);

router.get("/", async (_req, res) => {
  try {
    const categories = await Category.find().sort({ name: 1 });
    const counts = await Product.aggregate([
      { $group: { _id: "$category", count: { $sum: 1 } } },
    ]);
    const countMap = Object.fromEntries(counts.map((row) => [String(row._id), row.count]));
    res.json(
      categories.map((category) => ({
        ...category.toObject(),
        productCount: countMap[String(category._id)] || 0,
      }))
    );
  } catch (error) {
    res.status(500).json({ message: "Unable to load categories." });
  }
});

router.post("/", async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const description = String(req.body.description || "").trim();
    if (!name) return res.status(400).json({ message: "Category name is required." });

    const category = await Category.create({ name, description });
    res.status(201).json(category);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "A category with that name already exists." });
    }
    res.status(500).json({ message: "Unable to create category." });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const description = String(req.body.description || "").trim();
    if (!name) return res.status(400).json({ message: "Category name is required." });

    const category = await Category.findByIdAndUpdate(
      req.params.id,
      { name, description },
      { new: true, runValidators: true }
    );
    if (!category) return res.status(404).json({ message: "Category not found." });
    res.json(category);
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "A category with that name already exists." });
    }
    res.status(500).json({ message: "Unable to update category." });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    const inUse = await Product.exists({ category: req.params.id });
    if (inUse) {
      return res.status(400).json({ message: "Cannot delete a category that still has products." });
    }
    const category = await Category.findByIdAndDelete(req.params.id);
    if (!category) return res.status(404).json({ message: "Category not found." });
    res.json({ message: "Category deleted." });
  } catch (error) {
    res.status(500).json({ message: "Unable to delete category." });
  }
});

module.exports = router;
