const express = require("express");
const Product = require("../models/Product");
const Category = require("../models/Category");
const Sale = require("../models/Sale");
const { protect } = require("../middleware/auth");

const router = express.Router();
router.use(protect);

const TIMEZONE = "Asia/Manila";

function manilaDateKey(date = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function startOfManilaDay(date = new Date()) {
  return new Date(`${manilaDateKey(date)}T00:00:00+08:00`);
}

router.get("/", async (_req, res) => {
  try {
    const todayStart = startOfManilaDay();
    const weekStart = new Date(todayStart.getTime() - 6 * 24 * 60 * 60 * 1000);

    const [todayAgg] = await Sale.aggregate([
      { $match: { createdAt: { $gte: todayStart } } },
      {
        $group: {
          _id: null,
          sales: { $sum: 1 },
          revenue: { $sum: "$total" },
          retail: { $sum: { $cond: [{ $eq: ["$saleType", "retail"] }, "$total", 0] } },
          wholesale: { $sum: { $cond: [{ $eq: ["$saleType", "wholesale"] }, "$total", 0] } },
        },
      },
    ]);

    const weekRows = await Sale.aggregate([
      { $match: { createdAt: { $gte: weekStart } } },
      {
        $group: {
          _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt", timezone: TIMEZONE } },
          revenue: { $sum: "$total" },
          sales: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    const weekMap = Object.fromEntries(weekRows.map((row) => [row._id, row]));
    const weekly = Array.from({ length: 7 }, (_, index) => {
      const date = new Date(weekStart.getTime() + index * 24 * 60 * 60 * 1000);
      const key = manilaDateKey(date);
      return {
        date: key,
        label: date.toLocaleDateString("en-PH", { weekday: "short", timeZone: TIMEZONE }),
        revenue: weekMap[key]?.revenue || 0,
        sales: weekMap[key]?.sales || 0,
      };
    });

    const [productCount, categoryCount, lowStock, recentSales] = await Promise.all([
      Product.countDocuments({ isActive: true }),
      Category.countDocuments(),
      Product.find({ isActive: true, $expr: { $lte: ["$stock", "$reorderLevel"] } })
        .populate("category", "name")
        .sort({ stock: 1 })
        .limit(8),
      Sale.find().populate("cashier", "name").sort({ createdAt: -1 }).limit(8),
    ]);

    res.json({
      today: {
        sales: todayAgg?.sales || 0,
        revenue: todayAgg?.revenue || 0,
        retail: todayAgg?.retail || 0,
        wholesale: todayAgg?.wholesale || 0,
      },
      weekly,
      productCount,
      categoryCount,
      lowStock,
      recentSales,
    });
  } catch (error) {
    res.status(500).json({ message: "Unable to load dashboard." });
  }
});

module.exports = router;
