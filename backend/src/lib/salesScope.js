function canSeeAllSales(user) {
  return user?.role === "SuperAdmin" || user?.role === "Admin";
}

function ownSalesFilter(user) {
  if (!user) return { _id: { $exists: false } };
  if (canSeeAllSales(user)) return {};
  return { $or: [{ cashier: user._id }, { userId: user._id }] };
}

module.exports = { canSeeAllSales, ownSalesFilter };
