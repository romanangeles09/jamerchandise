export const TIMEZONE = "Asia/Manila";

export function peso(value) {
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
  }).format(Number(value) || 0);
}

export function formatDate(value) {
  return new Date(value).toLocaleString("en-PH", {
    timeZone: TIMEZONE,
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function weekdayShort(value) {
  const date = /^\d{4}-\d{2}-\d{2}$/.test(String(value))
    ? new Date(`${value}T12:00:00+08:00`)
    : new Date(value);
  return date.toLocaleDateString("en-PH", {
    timeZone: TIMEZONE,
    weekday: "short",
  });
}
