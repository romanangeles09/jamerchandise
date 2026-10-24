import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { LayoutDashboard, LogOut, Package, Settings, ShoppingCart } from "lucide-react";
import { useAuth } from "../context/AuthContext";

const nav = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: "/pos", label: "POS", icon: ShoppingCart },
  { to: "/inventory", label: "Inventory", icon: Package },
  { to: "/account", label: "Account Setting", icon: Settings },
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
          {nav.map((item) => {
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
            <span>{user?.name?.slice(0, 1) || "J"}</span>
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
