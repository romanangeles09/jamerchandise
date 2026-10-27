import { useState } from "react";
import { useAuth } from "../context/AuthContext";
import api, { getErrorMessage } from "../lib/api";

export default function AccountSetting() {
  const { user, setUser } = useAuth();
  const [name, setName] = useState(user?.name || "");
  const [email, setEmail] = useState(user?.email || "");
  const [avatarFile, setAvatarFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState(user?.avatarUrl || "");
  const [removeAvatar, setRemoveAvatar] = useState(false);
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [profileMessage, setProfileMessage] = useState("");
  const [passwordMessage, setPasswordMessage] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  async function saveProfile(event) {
    event.preventDefault();
    setError("");
    setProfileMessage("");
    setSaving(true);
    try {
      const form = new FormData();
      form.append("name", name);
      form.append("email", email);
      if (avatarFile) form.append("image", avatarFile);
      if (removeAvatar) form.append("removeImage", "true");
      const res = await api.put("/auth/profile", form);
      setUser(res.data.user);
      setAvatarFile(null);
      setRemoveAvatar(false);
      setPreviewUrl(res.data.user.avatarUrl || "");
      setProfileMessage("Profile saved.");
    } catch (err) {
      setError(getErrorMessage(err, "Unable to save profile."));
    } finally {
      setSaving(false);
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
            Profile photo
            <div className="image-picker avatar-picker">
              {previewUrl && !removeAvatar ? (
                <img src={previewUrl} alt="" className="avatar-preview" />
              ) : (
                <span className="avatar-preview placeholder">{name.slice(0, 1) || "J"}</span>
              )}
              <div>
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    if (!file) return;
                    setAvatarFile(file);
                    setPreviewUrl(URL.createObjectURL(file));
                    setRemoveAvatar(false);
                  }}
                />
                <small className="hint">JPG, PNG, WEBP, or GIF up to 2 MB.</small>
                {previewUrl && !removeAvatar ? (
                  <button
                    type="button"
                    className="danger-text"
                    onClick={() => {
                      setAvatarFile(null);
                      setPreviewUrl("");
                      setRemoveAvatar(true);
                    }}
                  >
                    Remove photo
                  </button>
                ) : null}
              </div>
            </div>
          </label>
          <label className="full">
            Full name
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label className="full">
            Email / Username
            <input type="text" value={email} onChange={(event) => setEmail(event.target.value)} required />
          </label>
          <label className="full">
            Role
            <input value={user?.role || ""} disabled />
          </label>
          <div className="modal-actions">
            <button type="submit" className="btn primary" disabled={saving}>
              {saving ? "Saving..." : "Save profile"}
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
