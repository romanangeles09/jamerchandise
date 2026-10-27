import { useEffect, useMemo, useState } from "react";
import { Minus, Plus, ScanBarcode, Trash2 } from "lucide-react";
import BarcodeScanner from "../components/BarcodeScanner";
import api, { getErrorMessage } from "../lib/api";
import { productImageSrc } from "../lib/image";
import { peso } from "../lib/money";
import Modal from "../components/Modal";

export default function POS() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("");
  const [saleType, setSaleType] = useState("retail");
  const [cart, setCart] = useState([]);
  const [discount, setDiscount] = useState(0);
  const [paymentMethod, setPaymentMethod] = useState("cash");
  const [amountPaid, setAmountPaid] = useState("");
  const [error, setError] = useState("");
  const [receipt, setReceipt] = useState(null);
  const [busy, setBusy] = useState(false);
  const [scanning, setScanning] = useState(false);
  const [scanNotice, setScanNotice] = useState("");

  useEffect(() => {
    Promise.all([
      api.get("/products", { params: { active: true } }),
      api.get("/categories"),
    ])
      .then(([productRes, categoryRes]) => {
        setProducts(productRes.data);
        setCategories(categoryRes.data);
      })
      .catch((err) => setError(getErrorMessage(err, "Unable to load POS catalog.")));
  }, []);

  const visibleProducts = useMemo(() => {
    const term = query.trim().toLowerCase();
    return products.filter((product) => {
      const matchesCategory = !category || product.category?._id === category;
      const matchesQuery =
        !term ||
        product.name.toLowerCase().includes(term) ||
        product.sku.toLowerCase().includes(term) ||
        product.barcode.toLowerCase().includes(term);
      return matchesCategory && matchesQuery;
    });
  }, [products, query, category]);

  const pricedCart = cart.map((item) => {
    const unitPrice = saleType === "wholesale" ? item.wholesalePrice : item.retailPrice;
    return { ...item, unitPrice, lineTotal: unitPrice * item.qty };
  });

  const subtotal = pricedCart.reduce((sum, item) => sum + item.lineTotal, 0);
  const safeDiscount = Math.min(Number(discount) || 0, subtotal);
  const total = Math.max(0, subtotal - safeDiscount);
  const paid = Number(amountPaid);
  const change = Number.isNaN(paid) ? 0 : paid - total;

  function hasWholesale(product) {
    return Number(product?.wholesalePrice) > 0;
  }

  function wholesaleMin(product) {
    const min = Number(product?.wholesaleMinQty);
    return Number.isFinite(min) && min > 0 ? min : 1;
  }

  function priceOf(product) {
    return saleType === "wholesale" && hasWholesale(product) ? product.wholesalePrice : product.retailPrice;
  }

  function findByCode(code) {
    const term = String(code || "").trim().toLowerCase();
    if (!term) return null;
    return products.find(
      (product) =>
        product.barcode?.toLowerCase() === term ||
        product.sku.toLowerCase() === term
    );
  }

  function addProduct(product) {
    if (saleType === "wholesale" && !hasWholesale(product)) {
      setError(`${product.name} is not available for wholesale.`);
      return false;
    }
    const minQty = saleType === "wholesale" ? wholesaleMin(product) : 1;
    const existing = cart.find((item) => item.product === product._id);
    const nextQty = existing ? existing.qty + 1 : minQty;

    if (nextQty > product.stock) {
      setError(`Not enough stock for ${product.name}.`);
      return false;
    }

    setError("");
    setCart((prev) => {
      const current = prev.find((item) => item.product === product._id);
      if (current) {
        return prev.map((item) =>
          item.product === product._id ? { ...item, qty: item.qty + 1 } : item
        );
      }
      return [
        ...prev,
        {
          product: product._id,
          name: product.name,
          sku: product.sku,
          unit: product.unit,
          stock: product.stock,
          retailPrice: product.retailPrice,
          wholesalePrice: product.wholesalePrice,
          wholesaleMinQty: product.wholesaleMinQty,
          qty: minQty,
        },
      ];
    });
    return true;
  }

  function addByCode(code) {
    const product = findByCode(code);
    if (!product) {
      setError(`No product found for ${code}.`);
      setScanNotice("");
      return false;
    }
    const added = addProduct(product);
    if (added) {
      setScanNotice(`Added ${product.name}`);
      setQuery("");
    }
    return added;
  }

  function updateQty(id, qty) {
    setCart((prev) =>
      prev.map((item) => {
        if (item.product !== id) return item;
        const minQty = saleType === "wholesale" ? wholesaleMin(item) : 1;
        return { ...item, qty: Math.min(item.stock, Math.max(minQty, qty)) };
      })
    );
  }

  async function checkout() {
    setError("");
    if (!pricedCart.length) {
      setError("Add items before checkout.");
      return;
    }
    if (Number.isNaN(paid) || paid < total) {
      setError("Amount paid must cover the total.");
      return;
    }

    setBusy(true);
    try {
      const res = await api.post("/sales", {
        saleType,
        discount: safeDiscount,
        amountPaid: paid,
        paymentMethod,
        items: pricedCart.map((item) => ({ product: item.product, qty: item.qty })),
      });
      setReceipt(res.data);
      setCart([]);
      setDiscount(0);
      setAmountPaid("");
      const productRes = await api.get("/products", { params: { active: true } });
      setProducts(productRes.data);
    } catch (err) {
      setError(getErrorMessage(err, "Checkout failed."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="pos-page">
      <div className="pos-catalog">
        <header className="page-head compact">
          <div>
            <span className="eyebrow">Register</span>
            <h1>Point of sale</h1>
          </div>
          <div className="segment">
            <button
              type="button"
              className={saleType === "retail" ? "active" : ""}
              onClick={() => setSaleType("retail")}
            >
              Retail
            </button>
            <button
              type="button"
              className={saleType === "wholesale" ? "active" : ""}
              onClick={() => setSaleType("wholesale")}
            >
              Wholesale
            </button>
          </div>
        </header>

        <div className="pos-filters">
          <div className="search-row">
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              onKeyDown={(event) => {
                if (event.key !== "Enter") return;
                if (findByCode(query)) {
                  event.preventDefault();
                  addByCode(query);
                }
              }}
              placeholder="Search name, SKU, or barcode"
            />
            <button type="button" className="btn scan-btn" onClick={() => { setScanning(true); setScanNotice(""); setError(""); }}>
              <ScanBarcode size={18} />
              Scan barcode
            </button>
          </div>
          <div className="chips">
            <button type="button" className={!category ? "chip active" : "chip"} onClick={() => setCategory("")}>
              All
            </button>
            {categories.map((item) => (
              <button
                key={item._id}
                type="button"
                className={category === item._id ? "chip active" : "chip"}
                onClick={() => setCategory(item._id)}
              >
                {item.name}
              </button>
            ))}
          </div>
        </div>

        <div className="product-grid">
          {visibleProducts.map((product) => (
            <button
              key={product._id}
              type="button"
              className="product-tile"
              onClick={() => addProduct(product)}
              disabled={product.stock < 1 || (saleType === "wholesale" && !hasWholesale(product))}
            >
              {product.hasImage ? (
                <img src={productImageSrc(product)} alt="" className="tile-photo" />
              ) : (
                <span className="tile-photo placeholder">{product.name.slice(0, 1)}</span>
              )}
              <small>{product.category?.name}</small>
              <strong>{product.name}</strong>
              <span>{peso(priceOf(product))}</span>
              <em>
                {product.stock} {product.unit}
                {saleType === "wholesale" && hasWholesale(product) ? ` · min ${wholesaleMin(product)}` : ""}
              </em>
            </button>
          ))}
        </div>
      </div>

      <aside className="cart">
        <h2>Cart</h2>
        {error ? <div className="alert">{error}</div> : null}
        {pricedCart.length === 0 ? (
          <p className="empty">Tap a product to add it.</p>
        ) : (
          <ul className="cart-list">
            {pricedCart.map((item) => (
              <li key={item.product}>
                <div>
                  <strong>{item.name}</strong>
                  <small>
                    {peso(item.unitPrice)} / {item.unit}
                  </small>
                </div>
                <div className="qty">
                  <button type="button" onClick={() => updateQty(item.product, item.qty - 1)}>
                    <Minus size={14} />
                  </button>
                  <span>{item.qty}</span>
                  <button type="button" onClick={() => updateQty(item.product, item.qty + 1)}>
                    <Plus size={14} />
                  </button>
                  <button type="button" className="danger-text" onClick={() => setCart((prev) => prev.filter((row) => row.product !== item.product))}>
                    <Trash2 size={14} />
                  </button>
                </div>
                <em>{peso(item.lineTotal)}</em>
              </li>
            ))}
          </ul>
        )}

        <label>
          Discount
          <input type="number" min="0" value={discount} onChange={(event) => setDiscount(event.target.value)} />
        </label>
        <label>
          Payment
          <select value={paymentMethod} onChange={(event) => setPaymentMethod(event.target.value)}>
            <option value="cash">Cash</option>
            <option value="gcash">GCash</option>
          </select>
        </label>
        <label>
          Amount paid
          <input
            type="number"
            min="0"
            step="0.01"
            value={amountPaid}
            onChange={(event) => setAmountPaid(event.target.value)}
            placeholder={String(total || "")}
          />
        </label>

        <dl className="totals">
          <div>
            <dt>Subtotal</dt>
            <dd>{peso(subtotal)}</dd>
          </div>
          <div>
            <dt>Discount</dt>
            <dd>{peso(safeDiscount)}</dd>
          </div>
          <div className="grand">
            <dt>Total</dt>
            <dd>{peso(total)}</dd>
          </div>
          <div>
            <dt>Change</dt>
            <dd>{peso(Math.max(0, change))}</dd>
          </div>
        </dl>

        <button type="button" className="btn primary full" onClick={checkout} disabled={busy}>
          {busy ? "Saving..." : "Complete sale"}
        </button>
      </aside>

      {scanning ? (
        <BarcodeScanner
          notice={scanNotice}
          error={error}
          onScan={addByCode}
          onClose={() => { setScanning(false); setScanNotice(""); }}
        />
      ) : null}

      {receipt ? (
        <Modal title={`Ticket ${receipt.invoiceNo}`} onClose={() => setReceipt(null)}>
          <p className="caps">{receipt.saleType} · {receipt.paymentMethod}</p>
          <ul className="stack-list compact">
            {receipt.items.map((item) => (
              <li key={item.sku}>
                <div>
                  <strong>
                    {item.qty} × {item.name}
                  </strong>
                  <small>{peso(item.unitPrice)}</small>
                </div>
                <em>{peso(item.lineTotal)}</em>
              </li>
            ))}
          </ul>
          <dl className="totals">
            <div className="grand">
              <dt>Total</dt>
              <dd>{peso(receipt.total)}</dd>
            </div>
            <div>
              <dt>Paid</dt>
              <dd>{peso(receipt.amountPaid)}</dd>
            </div>
            <div>
              <dt>Change</dt>
              <dd>{peso(receipt.change)}</dd>
            </div>
          </dl>
          <button type="button" className="btn primary full" onClick={() => setReceipt(null)}>
            New sale
          </button>
        </Modal>
      ) : null}
    </section>
  );
}
