import { Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "./context/AuthContext";
import { firstAllowedPath, hasAccess } from "./lib/access";
import AppLayout from "./layouts/AppLayout";
import AccountSetting from "./pages/AccountSetting";
import Dashboard from "./pages/Dashboard";
import Inventory from "./pages/Inventory";
import Login from "./pages/Login";
import POS from "./pages/POS";
import Transactions from "./pages/Transactions";
import UserAccess from "./pages/UserAccess";
import Cutoff from "./pages/Cutoff";

function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="splash">Loading JA Merchandise...</div>;
  if (!user) return <Navigate to="/login" replace />;
  return children;
}

function AccessRoute({ page, children }) {
  const { user } = useAuth();
  if (!hasAccess(user, page)) {
    return <Navigate to={firstAllowedPath(user)} replace />;
  }
  return children;
}

export default function App() {
  const { user } = useAuth();

  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route
          path="/"
          element={
            <AccessRoute page="dashboard">
              <Dashboard />
            </AccessRoute>
          }
        />
        <Route
          path="/transactions"
          element={
            <AccessRoute page="transactions">
              <Transactions />
            </AccessRoute>
          }
        />
        <Route
          path="/pos"
          element={
            <AccessRoute page="pos">
              <POS />
            </AccessRoute>
          }
        />
        <Route
          path="/cutoff"
          element={
            <AccessRoute page="cutoff">
              <Cutoff />
            </AccessRoute>
          }
        />
        <Route
          path="/inventory"
          element={
            <AccessRoute page="inventory">
              <Inventory />
            </AccessRoute>
          }
        />
        <Route
          path="/users"
          element={
            <AccessRoute page="users">
              <UserAccess />
            </AccessRoute>
          }
        />
        <Route
          path="/account"
          element={
            <AccessRoute page="account">
              <AccountSetting />
            </AccessRoute>
          }
        />
      </Route>
      <Route path="*" element={<Navigate to={user ? firstAllowedPath(user) : "/login"} replace />} />
    </Routes>
  );
}
