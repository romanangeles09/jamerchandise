import { useState } from "react";
import { useAuth } from "../context/AuthContext";
import api, { getErrorMessage } from "../lib/api";

export default function AccountSetting() {
  const { user, setUser } = useAuth();
  const [name, setName] = useState(user?.name || "");
  const [email, setEmail] = useState(user?.email || "");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [profileMessage, setProfileMessage] = useState("");
  const [passwordMessage, setPasswordMessage] = useState("");
  const [error, setError] = useState("");

  async function saveProfile(event) {
    event.preventDefault();
    setError("");
    setProfileMessage("");
    try {
      const res = await api.put("/auth/profile", { name, email });
      setUser(res.data.user);
      setProfileMessage("Profile saved.");
    } catch (err) {
      setError(getErrorMessage(err, "Unable to save profile."));
    }
  }

  async function savePassword(event) {
    event.preventDefault();
    setError("");
    setPasswordMessage("");
    try {
      await api.put("/auth/password", { currentPassword, newPassword });
      setCurrentPassword("");
      setNewPassword("");
      setPasswordMessage("Password updated.");
    } catch (err) {
      setError(getErrorMessage(err, "Unable to update password."));
    }
  }

  return (
    <section className="account-page">
      <header className="page-head">
        <div>
          <span className="eyebrow">Your account</span>
          <h1>Account Setting</h1>
        </div>
      </header>

      {error ? <div className="alert">{error}</div> : null}

      <div className="split">
        <form className="panel form-grid" onSubmit={saveProfile}>
          <h2>Profile</h2>
          {profileMessage ? <p className="success">{profileMessage}</p> : null}
          <label className="full">
            Full name
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label className="full">
            Email
            <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
          </label>
          <label className="full">
            Role
            <input value={user?.role || ""} disabled />
          </label>
          <div className="modal-actions">
            <button type="submit" className="btn primary">
              Save profile
            </button>
          </div>
        </form>

        <form className="panel form-grid" onSubmit={savePassword}>
          <h2>Password</h2>
          {passwordMessage ? <p className="success">{passwordMessage}</p> : null}
          <label className="full">
            Current password
            <input type="password" value={currentPassword} onChange={(event) => setCurrentPassword(event.target.value)} required />
          </label>
          <label className="full">
            New password
            <input type="password" minLength={6} value={newPassword} onChange={(event) => setNewPassword(event.target.value)} required />
          </label>
          <div className="modal-actions">
            <button type="submit" className="btn primary">
              Update password
            </button>
          </div>
        </form>
      </div>
    </section>
  );
}
