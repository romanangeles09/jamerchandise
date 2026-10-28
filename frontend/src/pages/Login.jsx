import { useEffect, useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { firstAllowedPath } from "../lib/access";
import api, { getErrorMessage } from "../lib/api";

function onlyDigits(value, maxLength) {
  return String(value || "").replace(/\D/g, "").slice(0, maxLength);
}

export default function Login() {
  const { user, loading, login, loginWithPin } = useAuth();
  const [mode, setMode] = useState("staff");
  const [staff, setStaff] = useState([]);
  const [userId, setUserId] = useState("");
  const [pincode, setPincode] = useState("");
  const [showPincode, setShowPincode] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    api
      .get("/auth/staff")
      .then((res) => setStaff(Array.isArray(res.data) ? res.data : []))
      .catch((err) => setError(getErrorMessage(err, "Unable to load staff.")));
  }, []);

  if (!loading && user) return <Navigate to={firstAllowedPath(user)} replace />;

  const isAdmin = mode === "admin";

  function switchMode(next) {
    setMode(next);
    setError("");
    setPassword("");
    setPincode("");
    setShowPassword(false);
    setShowPincode(false);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      if (isAdmin) {
        await login(email, password);
      } else {
        await loginWithPin(userId, pincode);
      }
    } catch (err) {
      setError(getErrorMessage(err, isAdmin ? "Invalid email/username or password." : "Invalid PIN."));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-art">
        <div className="login-badge">Est. wholesale & retail counter</div>
        <h1>JA Merchandise</h1>
        <p>
          A simple point of sale for bulk and walk-in sales, stock, and the daily
          counter.
        </p>
      </div>

      <form className="login-card" onSubmit={handleSubmit}>
        <span className="eyebrow">{isAdmin ? "Super Admin login" : "Staff login"}</span>
        <h2>{isAdmin ? "Sign in as Super Admin" : "Sign in to the register"}</h2>
        {error ? <div className="alert">{error}</div> : null}

        {isAdmin ? (
          <>
            <label>
              Email / Username
              <input
                type="text"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                autoComplete="username"
                placeholder="Super Admin email or username"
                required
              />
            </label>
            <label>
              Password
              <div className="password-field">
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  autoComplete="current-password"
                  required
                />
                <button
                  type="button"
                  className="icon-btn"
                  onClick={() => setShowPassword((open) => !open)}
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </label>
          </>
        ) : (
          <>
            <label>
              Staff
              <select value={userId} onChange={(event) => setUserId(event.target.value)} required>
                <option value="">{staff.length ? "Select staff" : "No staff with a PIN yet"}</option>
                {staff.map((member) => (
                  <option key={member.id} value={member.id}>
                    {member.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              PIN code
              <div className="password-field">
                <input
                  type={showPincode ? "text" : "password"}
                  inputMode="numeric"
                  pattern="[0-9]{8}"
                  maxLength={8}
                  value={pincode}
                  onChange={(event) => setPincode(onlyDigits(event.target.value, 8))}
                  autoComplete="off"
                  placeholder="8 digits"
                  required
                />
                <button
                  type="button"
                  className="icon-btn"
                  onClick={() => setShowPincode((open) => !open)}
                  aria-label={showPincode ? "Hide PIN code" : "Show PIN code"}
                >
                  {showPincode ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </label>
          </>
        )}

        <button type="submit" className="btn primary full" disabled={submitting}>
          {submitting ? "Signing in..." : "Enter POS"}
        </button>
        <button type="button" className="login-switch" onClick={() => switchMode(isAdmin ? "staff" : "admin")}>
          {isAdmin ? "Back to staff login" : "Super Admin login"}
        </button>
      </form>
    </div>
  );
}
