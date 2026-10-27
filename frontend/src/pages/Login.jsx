import { useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { firstAllowedPath } from "../lib/access";
import { getErrorMessage } from "../lib/api";

export default function Login() {
  const { user, loading, login } = useAuth();
  const [email, setEmail] = useState("jabulakan@gmail.com");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (!loading && user) return <Navigate to={firstAllowedPath(user)} replace />;

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      await login(email, password);
    } catch (err) {
      setError(getErrorMessage(err, "Invalid email/username or password."));
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
        <span className="eyebrow">Staff login</span>
        <h2>Sign in to the register</h2>
        {error ? <div className="alert">{error}</div> : null}

        <label>
          Email / Username
          <input
            type="text"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            autoComplete="username"
            placeholder="cashier1 or email"
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
        <button type="submit" className="btn primary full" disabled={submitting}>
          {submitting ? "Signing in..." : "Enter POS"}
        </button>
        <p className="hint">Seeded SuperAdmin: jabulakan@gmail.com</p>
      </form>
    </div>
  );
}
