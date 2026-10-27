import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { ClipboardCheck, LayoutDashboard, LogOut, Package, Receipt, Settings, ShoppingCart, Users } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { hasAccess } from "../lib/access";

const nav = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true, page: "dashboard" },
  { to: "/transactions", label: "Transactions", icon: Receipt, page: "transactions" },
  { to: "/pos", label: "POS", icon: ShoppingCart, page: "pos" },
  { to: "/cutoff", label: "Cutoff", icon: ClipboardCheck, page: "cutoff" },
  { to: "/inventory", label: "Inventory", icon: Package, page: "inventory" },
  { to: "/users", label: "User Access", icon: Users, page: "users" },
  { to: "/account", label: "Account Setting", icon: Settings, page: "account" },
];

export default function AppLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate("/login");
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">JA</span>
          <div>
            <strong>JA Merchandise</strong>
            <small>Wholesale & Retail POS</small>
          </div>
        </div>

        <nav>
          {nav
            .filter((item) => hasAccess(user, item.page))
            .map((item) => {
              const Icon = item.icon;
              return (
                <NavLink key={item.to} to={item.to} end={item.end} className="nav-link">
                  <Icon size={18} />
                  {item.label}
                </NavLink>
              );
            })}
        </nav>

        <div className="sidebar-foot">
          <div className="user-chip">
            {user?.avatarUrl ? (
              <img src={user.avatarUrl} alt="" className="user-avatar" />
            ) : (
              <span>{user?.name?.slice(0, 1) || "J"}</span>
            )}
            <div>
              <strong>{user?.name}</strong>
              <small>{user?.role}</small>
            </div>
          </div>
          <button type="button" className="logout-btn" onClick={handleLogout}>
            <LogOut size={16} />
            Log out
          </button>
        </div>
      </aside>

      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
