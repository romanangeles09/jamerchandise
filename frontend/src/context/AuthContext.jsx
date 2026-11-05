import { createContext, useContext, useEffect, useMemo, useState } from "react";
import api, { getErrorMessage } from "../lib/api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Migrate away from persistent login; session ends when the tab/app closes.
    localStorage.removeItem("ja_token");
    const token = sessionStorage.getItem("ja_token");
    if (!token) {
      setLoading(false);
      return;
    }

    api
      .get("/auth/me")
      .then((res) => setUser(res.data.user))
      .catch(() => {
        sessionStorage.removeItem("ja_token");
        setUser(null);
      })
      .finally(() => setLoading(false));
  }, []);

  const value = useMemo(
    () => ({
      user,
      loading,
      async login(email, password) {
        const res = await api.post("/auth/login", { email, password });
        sessionStorage.setItem("ja_token", res.data.token);
        localStorage.removeItem("ja_token");
        setUser(res.data.user);
        return res.data.user;
      },
      async loginWithPin(userId, pincode) {
        const res = await api.post("/auth/pin-login", { userId, pincode });
        sessionStorage.setItem("ja_token", res.data.token);
        localStorage.removeItem("ja_token");
        setUser(res.data.user);
        return res.data.user;
      },
      logout() {
        sessionStorage.removeItem("ja_token");
        localStorage.removeItem("ja_token");
        setUser(null);
      },
      setUser,
    }),
    [user, loading]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within AuthProvider");
  return context;
}

export { getErrorMessage };
