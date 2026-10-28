import { useEffect, useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import api, { getErrorMessage } from "../lib/api";
import { ACCESS_PAGES } from "../lib/access";
import Modal from "../components/Modal";

const emptyUser = {
  name: "",
  role: "Cashier",
  email: "",
  password: "",
  pincode: "",
  access: ["pos", "cutoff", "account"],
  isActive: true,
};

function onlyDigits(value, maxLength) {
  return String(value || "").replace(/\D/g, "").slice(0, maxLength);
}

export default function UserAccess() {
  const [users, setUsers] = useState([]);
  const [error, setError] = useState("");
  const [form, setForm] = useState(null);
  const [saving, setSaving] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showPincode, setShowPincode] = useState(false);

  async function load() {
    const res = await api.get("/users");
    setUsers(res.data);
  }

  useEffect(() => {
    load().catch((err) => setError(getErrorMessage(err, "Unable to load users.")));
  }, []);

  function toggleAccess(page) {
    setForm((current) => {
      const has = current.access.includes(page);
      return {
        ...current,
        access: has ? current.access.filter((item) => item !== page) : [...current.access, page],
      };
    });
  }

  async function saveUser(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const payload = {
        name: form.name,
        email: form.email,
        role: form.role,
        access: form.access,
        isActive: form.isActive !== false,
      };
      if (form.password) payload.password = form.password;
      if (form.pincode) payload.pincode = form.pincode;
      if (form._id) {
        await api.put(`/users/${form._id}`, payload);
      } else {
        await api.post("/users", payload);
      }
      setForm(null);
      await load();
    } catch (err) {
      setError(getErrorMessage(err, "Unable to save user."));
    } finally {
      setSaving(false);
    }
  }

  async function removeUser(id) {
    if (!window.confirm("Delete this user?")) return;
    try {
      await api.delete(`/users/${id}`);
      await load();
    } catch (err) {
      setError(getErrorMessage(err, "Unable to delete user."));
    }
  }

  return (
    <section>
      <header className="page-head">
        <div>
          <span className="eyebrow">Staff logins</span>
          <h1>User Access</h1>
        </div>
        <button type="button" className="btn primary" onClick={() => { setShowPassword(false); setShowPincode(false); setForm({ ...emptyUser }); }}>
          Add user
        </button>
      </header>

      {error ? <div className="alert">{error}</div> : null}

      <div className="table-wrap panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email / username</th>
              <th>Role</th>
              <th>Access</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {users.length === 0 ? (
              <tr>
                <td colSpan={5} className="empty">
                  No users yet.
                </td>
              </tr>
            ) : (
              users.map((user) => (
                <tr key={user.id}>
                  <td>
                    <strong>{user.name}</strong>
                    <small className="block">{user.isActive === false ? "Disabled" : "Active"}</small>
                  </td>
                  <td>{user.email}</td>
                  <td>{user.role}</td>
                  <td>
                    <small>
                      {ACCESS_PAGES.filter((page) => user.access?.includes(page.id))
                        .map((page) => page.label)
                        .join(", ") || "None"}
                    </small>
                  </td>
                  <td className="row-actions">
                    <button
                      type="button"
                      onClick={() => {
                        setShowPassword(false);
                        setShowPincode(false);
                        setForm({
                          _id: user.id,
                          name: user.name,
                          email: user.email,
                          role: user.role,
                          access: user.access || [],
                          password: "",
                          pincode: "",
                          isActive: user.isActive !== false,
                        });
                      }}
                    >
                      Edit
                    </button>
                    {user.role !== "SuperAdmin" ? (
                      <button type="button" className="danger-text" onClick={() => removeUser(user.id)}>
                        Delete
                      </button>
                    ) : null}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {form ? (
        <Modal title={form._id ? "Edit user" : "New user"} onClose={() => setForm(null)}>
          <form className="form-grid" onSubmit={saveUser} autoComplete="off">
            <input className="autofill-trap" type="text" name="fake-username" autoComplete="username" tabIndex={-1} aria-hidden="true" />
            <input className="autofill-trap" type="password" name="fake-password" autoComplete="current-password" tabIndex={-1} aria-hidden="true" />
            <label>
              Name
              <input
                value={form.name}
                onChange={(event) => setForm({ ...form, name: event.target.value })}
                placeholder="Cashier 1"
                autoComplete="off"
                required
              />
            </label>
            <label>
              Role
              {form.role === "SuperAdmin" ? (
                <input value="SuperAdmin" disabled />
              ) : (
                <select value={form.role} onChange={(event) => setForm({ ...form, role: event.target.value })}>
                  <option value="Cashier">Cashier</option>
                  <option value="Admin">Admin</option>
                </select>
              )}
            </label>
            <label>
              Email / username
              <input
                name="staff-login"
                value={form.email}
                onChange={(event) => setForm({ ...form, email: event.target.value })}
                placeholder="cashier1"
                autoComplete="off"
                required
              />
            </label>
            <label>
              Password
              <div className="password-field">
                <input
                  name="staff-password"
                  type={showPassword ? "text" : "password"}
                  minLength={form._id ? undefined : 6}
                  value={form.password}
                  onChange={(event) => setForm({ ...form, password: event.target.value })}
                  placeholder={form._id ? "Leave blank to keep current" : "At least 6 characters"}
                  autoComplete="new-password"
                  required={!form._id}
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
            <label>
              PIN code
              <div className="password-field">
                <input
                  name="staff-pincode"
                  type={showPincode ? "text" : "password"}
                  inputMode="numeric"
                  pattern="[0-9]{8}"
                  maxLength={8}
                  value={form.pincode}
                  onChange={(event) => setForm({ ...form, pincode: onlyDigits(event.target.value, 8) })}
                  placeholder={form._id ? "Leave blank to keep current" : "8 digits"}
                  autoComplete="off"
                  required={!form._id}
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

            <fieldset className="access-list">
              <legend>Can access</legend>
              {ACCESS_PAGES.map((page) => (
                <label key={page.id} className="check">
                  <input
                    type="checkbox"
                    checked={form.access.includes(page.id)}
                    onChange={() => toggleAccess(page.id)}
                  />
                  {page.label}
                </label>
              ))}
            </fieldset>

            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setForm(null)}>
                Cancel
              </button>
              <button type="submit" className="btn primary" disabled={saving}>
                {saving ? "Saving..." : "Save user"}
              </button>
            </div>
          </form>
        </Modal>
      ) : null}
    </section>
  );
}
