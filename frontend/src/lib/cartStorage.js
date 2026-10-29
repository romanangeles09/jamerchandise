const PREFIX = "ja_cart_";

export function emptyCartState() {
  return {
    cart: [],
    saleType: "retail",
    discount: 0,
    paymentMethod: "cash",
    amountPaid: "",
    gcashTxnNo: "",
  };
}

function normalizeItem(item) {
  if (!item || !item.product) return null;
  const qty = Number(item.qty);
  if (!Number.isFinite(qty) || qty <= 0) return null;
  return {
    product: item.product,
    name: item.name || "",
    sku: item.sku || "",
    unit: item.unit || "pc",
    stock: Number(item.stock) || 0,
    retailPrice: Number(item.retailPrice) || 0,
    wholesalePrice: item.wholesalePrice == null ? null : Number(item.wholesalePrice),
    wholesaleMinQty: item.wholesaleMinQty == null ? null : Number(item.wholesaleMinQty),
    qty,
  };
}

export function loadCartState(userId) {
  if (!userId) return emptyCartState();
  try {
    const raw = localStorage.getItem(`${PREFIX}${userId}`);
    if (!raw) return emptyCartState();
    const parsed = JSON.parse(raw);
    const cart = Array.isArray(parsed.cart) ? parsed.cart.map(normalizeItem).filter(Boolean) : [];
    return {
      cart,
      saleType: parsed.saleType === "wholesale" ? "wholesale" : "retail",
      discount: parsed.discount ?? 0,
      paymentMethod: parsed.paymentMethod === "gcash" ? "gcash" : "cash",
      amountPaid: parsed.amountPaid ?? "",
      gcashTxnNo: parsed.gcashTxnNo ?? "",
    };
  } catch {
    return emptyCartState();
  }
}

export function saveCartState(userId, state) {
  if (!userId) return;
  localStorage.setItem(
    `${PREFIX}${userId}`,
    JSON.stringify({
      cart: Array.isArray(state.cart) ? state.cart : [],
      saleType: state.saleType === "wholesale" ? "wholesale" : "retail",
      discount: state.discount ?? 0,
      paymentMethod: state.paymentMethod === "gcash" ? "gcash" : "cash",
      amountPaid: state.amountPaid ?? "",
      gcashTxnNo: state.gcashTxnNo ?? "",
    })
  );
}
