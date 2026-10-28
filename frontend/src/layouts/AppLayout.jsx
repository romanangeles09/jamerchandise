import { useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { ChevronLeft, ChevronRight, ClipboardCheck, LayoutDashboard, LogOut, Package, Receipt, Settings, ShoppingCart, Users } from "lucide-react";
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
  const [collapsed, setCollapsed] = useState(() => localStorage.getItem("ja_nav_collapsed") === "1");

  function handleLogout() {
    logout();
    navigate("/login");
  }

  function toggleNav() {
    setCollapsed((open) => {
      const next = !open;
      localStorage.setItem("ja_nav_collapsed", next ? "1" : "0");
      return next;
    });
  }

  return (
    <div className={collapsed ? "shell collapsed" : "shell"}>
      <div className={collapsed ? "sidebar-wrap collapsed" : "sidebar-wrap"}>
      <aside className={collapsed ? "sidebar collapsed" : "sidebar"}>
        <div className="brand">
          <span className="brand-mark">JA</span>
          <div className="brand-text">
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
                <NavLink key={item.to} to={item.to} end={item.end} className="nav-link" title={item.label}>
                  <Icon size={18} />
                  <span>{item.label}</span>
                </NavLink>
              );
            })}
        </nav>

        <div className="sidebar-foot">
          <div className="user-chip" title={`${user?.name || ""} · ${user?.role || ""}`}>
            {user?.avatarUrl ? (
              <img src={user.avatarUrl} alt="" className="user-avatar" />
            ) : (
              <span>{user?.name?.slice(0, 1) || "J"}</span>
            )}
            <div className="user-meta">
              <strong>{user?.name}</strong>
              <small>{user?.role}</small>
            </div>
          </div>
          <button type="button" className="logout-btn" onClick={handleLogout} title="Log out">
            <LogOut size={16} />
            <span>Log out</span>
          </button>
        </div>
      </aside>
      </div>

      <main className="content">
        <Outlet />
      </main>

      <button
        type="button"
        className="nav-toggle"
        onClick={toggleNav}
        aria-label={collapsed ? "Show navigation" : "Hide navigation"}
        title={collapsed ? "Show navigation" : "Hide navigation"}
      >
        {collapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
      </button>
    </div>
  );
}
