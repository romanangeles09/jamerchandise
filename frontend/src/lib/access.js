export const ACCESS_PAGES = [
  { id: "dashboard", label: "Dashboard", path: "/" },
  { id: "transactions", label: "Transactions", path: "/transactions" },
  { id: "pos", label: "POS", path: "/pos" },
  { id: "cutoff", label: "Cutoff", path: "/cutoff" },
  { id: "inventory", label: "Inventory", path: "/inventory" },
  { id: "users", label: "User Access", path: "/users" },
  { id: "account", label: "Account Setting", path: "/account" },
];

export function hasAccess(user, page) {
  if (!user) return false;
  if (user.role === "SuperAdmin") return true;
  const access = Array.isArray(user.access) ? user.access : [];
  if (page === "cutoff" && access.includes("pos")) return true;
  return access.includes(page);
}

export function firstAllowedPath(user) {
  const page = ACCESS_PAGES.find((item) => hasAccess(user, item.id));
  return page?.path || "/login";
}
