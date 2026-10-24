import { useState } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { getErrorMessage } from "../lib/api";

export default function Login() {
  const { user, loading, login } = useAuth();
  const [email, setEmail] = useState("jabulakan@gmail.com");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (!loading && user) return <Navigate to="/" replace />;

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    setSubmitting(true);
    try {
      await login(email, password);
    } catch (err) {
      setError(getErrorMessage(err, "Invalid email or password."));
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
          Email
          <input
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            autoComplete="username"
            required
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="current-password"
            required
          />
        </label>
        <button type="submit" className="btn primary full" disabled={submitting}>
          {submitting ? "Signing in..." : "Enter POS"}
        </button>
        <p className="hint">Seeded SuperAdmin: jabulakan@gmail.com</p>
      </form>
    </div>
  );
}
