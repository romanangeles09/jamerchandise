import axios from "axios";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "/api",
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("ja_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const url = error.config?.url || "";
    const isLoginAttempt =
      url.includes("/auth/login") ||
      url.includes("/auth/pin-login") ||
      url.includes("/auth/verify-superadmin-pin");
    if (error.response?.status === 401 && !isLoginAttempt) {
      localStorage.removeItem("ja_token");
      if (window.location.pathname !== "/login") {
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);

export function getErrorMessage(error, fallback = "Something went wrong.") {
  return error.response?.data?.message || fallback;
}

export default api;
