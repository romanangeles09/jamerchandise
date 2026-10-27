const express = require("express");
const Product = require("../models/Product");
const Category = require("../models/Category");
const Sale = require("../models/Sale");
const { protect } = require("../middleware/auth");
const { ownSalesFilter } = require("../lib/salesScope");

const router = express.Router();
router.use(protect);

const TIMEZONE = "Asia/Manila";
const MONTH_LABELS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function manilaDateKey(date = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function manilaYear(date = new Date()) {
  return Number(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: TIMEZONE,
      year: "numeric",
    }).format(date)
  );
}

function startOfManilaDay(date = new Date()) {
  return new Date(`${manilaDateKey(date)}T00:00:00+08:00`);
}

function requestedYear(value) {
  const year = Number(value);
  const current = manilaYear();
  if (!Number.isInteger(year) || year < 2000 || year > current + 1) return current;
  return year;
}

function requestedMonth(value) {
  const month = Number(value);
  if (!Number.isInteger(month) || month < 1 || month > 12) return null;
  return month;
}

function monthRange(year, month) {
  const start = new Date(`${year}-${String(month).padStart(2, "0")}-01T00:00:00+08:00`);
  const next = month === 12 ? `${year + 1}-01-01` : `${year}-${String(month + 1).padStart(2, "0")}-01`;
  return { start, end: new Date(`${next}T00:00:00+08:00`) };
}

function summarizeSales(sales) {
  const productsMap = new Map();
  const cashiersMap = new Map();
  let tickets = 0;
  let itemCount = 0;
  let subtotal = 0;
  let discount = 0;
  let total = 0;
  let cash = 0;
  let gcash = 0;
  let retail = 0;
  let wholesale = 0;

  for (const sale of sales) {
    tickets += 1;
    subtotal += sale.subtotal;
    discount += sale.discount;
    total += sale.total;
    if (sale.paymentMethod === "gcash") gcash += sale.total;
    if (sale.paymentMethod === "cash") cash += sale.total;
    if (sale.saleType === "wholesale") wholesale += sale.total;
    else retail += sale.total;

    const cashierKey = String(sale.cashier?._id || sale.cashier || "unknown");
    const cashierRow = cashiersMap.get(cashierKey) || {
      name: sale.cashier?.name || "—",
      tickets: 0,
      total: 0,
    };
    cashierRow.tickets += 1;
    cashierRow.total += sale.total;
    cashiersMap.set(cashierKey, cashierRow);

    for (const item of sale.items) {
      itemCount += item.qty;
      const product = productsMap.get(item.sku) || {
        sku: item.sku,
        name: item.name,
        qty: 0,
        amount: 0,
      };
      product.qty += item.qty;
      product.amount += item.lineTotal;
      productsMap.set(item.sku, product);
    }
  }

  return {
    summary: {
      tickets,
      itemCount,
      subtotal: Number(subtotal.toFixed(2)),
      discount: Number(discount.toFixed(2)),
      total: Number(total.toFixed(2)),
      cash: Number(cash.toFixed(2)),
      gcash: Number(gcash.toFixed(2)),
      retail: Number(retail.toFixed(2)),
      wholesale: Number(wholesale.toFixed(2)),
    },
    products: [...productsMap.values()].sort((a, b) => b.amount - a.amount),
    cashiers: [...cashiersMap.values()]
      .map((row) => ({ ...row, total: Number(row.total.toFixed(2)) }))
      .sort((a, b) => b.total - a.total),
  };
}

async function monthlyBreakdown(saleScope, year) {
  const start = new Date(`${year}-01-01T00:00:00+08:00`);
  const end = new Date(`${year}-12-31T23:59:59.999+08:00`);
  const rows = await Sale.aggregate([
    { $match: { createdAt: { $gte: start, $lte: end }, ...saleScope } },
    {
      $group: {
        _id: { $dateToString: { format: "%m", date: "$createdAt", timezone: TIMEZONE } },
        revenue: { $sum: "$total" },
        sales: { $sum: 1 },
      },
    },
  ]);
  const map = Object.fromEntries(rows.map((row) => [row._id, row]));
  return MONTH_LABELS.map((label, index) => {
    const key = String(index + 1).padStart(2, "0");
    return {
      month: index + 1,
      label,
      revenue: Number((map[key]?.revenue || 0).toFixed(2)),
      sales: map[key]?.sales || 0,
    };
  });
}

async function availableYears(saleScope) {
  const current = manilaYear();
  const rows = await Sale.aggregate([
    { $match: saleScope },
    {
      $group: {
        _id: { $dateToString: { format: "%Y", date: "$createdAt", timezone: TIMEZONE } },
      },
    },
  ]);
  const years = new Set(rows.map((row) => Number(row._id)).filter((year) => year >= 2000));
  years.add(current);
  years.add(current - 1);
  years.add(current - 2);
  return [...years].sort((a, b) => b - a);
}

router.get("/month", async (req, res) => {
  try {
    const year = requestedYear(req.query.year);
    const month = requestedMonth(req.query.month);
    if (!month) {
      return res.status(400).json({ message: "Pick a valid month." });
    }

    const { start, end } = monthRange(year, month);
    const match = { createdAt: { $gte: start, $lt: end }, ...ownSalesFilter(req.user) };
    const sales = await Sale.find(match).populate("cashier", "name").sort({ createdAt: -1 }).limit(200);
    const details = summarizeSales(sales);

    res.json({
      year,
      month,
      label: MONTH_LABELS[month - 1],
      ...details,
      sales,
    });
  } catch (error) {
    res.status(500).json({ message: "Unable to load month details." });
  }
});

router.get("/", async (req, res) => {
  try {
    const todayStart = startOfManilaDay();
    const weekStart = new Date(todayStart.getTime() - 6 * 24 * 60 * 60 * 1000);
    const saleScope = ownSalesFilter(req.user);
    const year = requestedYear(req.query.year);

    const [todayAgg] = await Sale.aggregate([
      { $match: { createdAt: { $gte: todayStart }, ...saleScope } },
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
      { $match: { createdAt: { $gte: weekStart }, ...saleScope } },
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

    const [productCount, categoryCount, lowStock, recentSales, monthly, years] = await Promise.all([
      Product.countDocuments({ isActive: true }),
      Category.countDocuments(),
      Product.find({ isActive: true, $expr: { $lte: ["$stock", "$reorderLevel"] } })
        .populate("category", "name")
        .sort({ stock: 1 })
        .limit(8),
      Sale.find(saleScope).populate("cashier", "name").sort({ createdAt: -1 }).limit(8),
      monthlyBreakdown(saleScope, year),
      availableYears(saleScope),
    ]);

    res.json({
      today: {
        sales: todayAgg?.sales || 0,
        revenue: todayAgg?.revenue || 0,
        retail: todayAgg?.retail || 0,
        wholesale: todayAgg?.wholesale || 0,
      },
      weekly,
      year,
      years,
      monthly,
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
