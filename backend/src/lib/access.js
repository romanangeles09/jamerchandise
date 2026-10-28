const ACCESS_PAGES = ["dashboard", "transactions", "pos", "cutoff", "inventory", "users", "account"];

function allAccess() {
  return [...ACCESS_PAGES];
}

function resolveAccess(user) {
  if (!user) return [];
  if (user.role === "SuperAdmin") return allAccess();
  const access = Array.isArray(user.access)
    ? user.access.filter((page) => ACCESS_PAGES.includes(page))
    : [];
  if (!access.length) return ["account"];
  return access;
}

function hasAccess(user, page) {
  return resolveAccess(user).includes(page);
}

module.exports = { ACCESS_PAGES, allAccess, resolveAccess, hasAccess };
