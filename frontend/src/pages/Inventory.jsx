import { useEffect, useState } from "react";
import api, { getErrorMessage } from "../lib/api";
import Code128 from "../components/Code128";
import Pagination from "../components/Pagination";
import { printBarcodeLabel } from "../lib/barcodeLabel";
import { nextCode128Barcode } from "../lib/code128";
import { peso } from "../lib/money";
import Modal from "../components/Modal";

const emptyProduct = {
  name: "",
  alias: "",
  sku: "",
  barcode: "",
  category: "",
  unit: "pc",
  retailPrice: "",
  wholesalePrice: "",
  wholesaleMinQty: "",
  costPrice: "",
  stock: "",
  reorderLevel: 10,
  isActive: true,
};

function skuPrefix(categoryName) {
  const word = String(categoryName || "").trim().split(/\s+/)[0] || "PRD";
  const letters = word.replace(/[^A-Za-z0-9]/g, "").slice(0, 3).toUpperCase();
  const base = letters || "PRD";
  return base.length >= 3 ? base.slice(0, 3) : base.padEnd(3, "X");
}

function nextSku(categoryId, products, categories) {
  const category = categories.find((item) => item._id === categoryId);
  if (!category) return "";
  const prefix = skuPrefix(category.name);
  let max = 0;
  for (const product of products) {
    const sku = String(product.sku || "").toUpperCase();
    if (!sku.startsWith(`${prefix}-`)) continue;
    const n = Number(sku.slice(prefix.length + 1));
    if (Number.isInteger(n) && n > max) max = n;
  }
  return `${prefix}-${String(max + 1).padStart(3, "0")}`;
}

function derivedCost(wholesalePrice, wholesaleMinQty) {
  if (wholesalePrice === "" || wholesalePrice == null) return "";
  const price = Number(wholesalePrice);
  if (!Number.isFinite(price) || price < 0) return "";
  const qty = wholesaleMinQty === "" || wholesaleMinQty == null ? 1 : Number(wholesaleMinQty);
  if (!Number.isFinite(qty) || qty < 1) return "";
  return String(Number((price * qty).toFixed(2)));
}

const emptyCategory = { name: "", description: "" };
const PAGE_SIZE = 25;

export default function Inventory() {
  const [tab, setTab] = useState("products");
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState("");
  const [productForm, setProductForm] = useState(null);
  const [barcodeCopies, setBarcodeCopies] = useState(1);
  const [categoryForm, setCategoryForm] = useState(null);
  const [saving, setSaving] = useState(false);

  async function loadCategories() {
    const categoryRes = await api.get("/categories");
    setCategories(categoryRes.data);
  }

  async function loadProducts(nextPage = page, nextQuery = query) {
    const productRes = await api.get("/products", {
      params: {
        page: nextPage,
        limit: PAGE_SIZE,
        ...(nextQuery.trim() ? { q: nextQuery.trim() } : {}),
      },
    });
    const data = productRes.data;
    setProducts(data.items || []);
    setPage(data.page || 1);
    setPages(data.pages || 1);
    setTotal(data.total || 0);
  }

  async function load(nextPage = page, nextQuery = query) {
    await Promise.all([loadProducts(nextPage, nextQuery), loadCategories()]);
  }

  useEffect(() => {
    load(1, "").catch((err) => setError(getErrorMessage(err, "Unable to load inventory.")));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (tab !== "products") return undefined;
    const handle = window.setTimeout(() => {
      loadProducts(1, query).catch((err) => setError(getErrorMessage(err, "Unable to load products.")));
    }, 250);
    return () => window.clearTimeout(handle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query]);

  async function saveProduct(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const payload = {
        name: productForm.name,
        alias: productForm.alias || "",
        sku: productForm.sku,
        barcode: productForm.barcode || "",
        category: productForm.category,
        unit: productForm.unit || "pc",
        retailPrice: Number(productForm.retailPrice),
        wholesalePrice:
          productForm.wholesalePrice === "" || productForm.wholesalePrice == null
            ? ""
            : Number(productForm.wholesalePrice),
        wholesaleMinQty:
          productForm.wholesaleMinQty === "" || productForm.wholesaleMinQty == null
            ? ""
            : Number(productForm.wholesaleMinQty),
        costPrice:
          productForm.costPrice === "" || productForm.costPrice == null ? "" : Number(productForm.costPrice),
        stock: Number(productForm.stock || 0),
        reorderLevel: Number(productForm.reorderLevel || 10),
        isActive: productForm.isActive !== false,
      };
      if (productForm._id) {
        await api.put(`/products/${productForm._id}`, payload);
      } else {
        await api.post("/products", payload);
      }
      setProductForm(null);
      await load(1, query);
    } catch (err) {
      setError(getErrorMessage(err, "Unable to save product."));
    } finally {
      setSaving(false);
    }
  }

  async function saveCategory(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      if (categoryForm._id) {
        await api.put(`/categories/${categoryForm._id}`, categoryForm);
      } else {
        await api.post("/categories", categoryForm);
      }
      setCategoryForm(null);
      await load();
    } catch (err) {
      setError(getErrorMessage(err, "Unable to save category."));
    } finally {
      setSaving(false);
    }
  }

  async function removeProduct(id) {
    if (!window.confirm("Delete this product?")) return;
    await api.delete(`/products/${id}`);
    await loadProducts(page, query);
  }

  async function removeCategory(id) {
    if (!window.confirm("Delete this category?")) return;
    try {
      await api.delete(`/categories/${id}`);
      await load();
    } catch (err) {
      setError(getErrorMessage(err, "Unable to delete category."));
    }
  }

  return (
    <section>
      <header className="page-head">
        <div>
          <span className="eyebrow">Stock room</span>
          <h1>Inventory</h1>
        </div>
        <div className="page-actions">
          {tab === "products" ? (
            <button
              type="button"
              className="btn primary"
              onClick={() => {
                const category = categories[0]?._id || "";
                setError("");
                setBarcodeCopies(1);
                const sku = nextSku(category, products, categories);
                setProductForm({
                  ...emptyProduct,
                  category,
                  sku,
                  barcode: nextCode128Barcode(products),
                });
              }}
            >
              Add product
            </button>
          ) : (
            <button type="button" className="btn primary" onClick={() => setCategoryForm({ ...emptyCategory })}>
              Add category
            </button>
          )}
        </div>
      </header>

      <div className="segment">
        <button type="button" className={tab === "products" ? "active" : ""} onClick={() => setTab("products")}>
          Products
        </button>
        <button type="button" className={tab === "categories" ? "active" : ""} onClick={() => setTab("categories")}>
          Categories
        </button>
      </div>

      {error ? <div className="alert">{error}</div> : null}

      {tab === "products" ? (
        <>
          <input
            className="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search products"
          />
          <div className="table-wrap panel">
            <table>
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Category</th>
                  <th>Retail</th>
                  <th>Wholesale</th>
                  <th>Stock</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {products.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="empty">
                      No products yet.
                    </td>
                  </tr>
                ) : (
                  products.map((product) => (
                    <tr key={product._id}>
                      <td>
                        <strong>{product.name}</strong>
                        {product.alias ? <small className="block">{product.alias}</small> : null}
                      </td>
                      <td>{product.category?.name}</td>
                      <td>{peso(product.retailPrice)}</td>
                      <td>
                        {Number(product.wholesalePrice) > 0 ? (
                          <>
                            {peso(product.wholesalePrice)}
                            <small className="block">min {product.wholesaleMinQty || 1}</small>
                          </>
                        ) : (
                          "—"
                        )}
                      </td>
                      <td className={product.stock <= product.reorderLevel ? "warn" : ""}>
                        {product.stock} {product.unit}
                      </td>
                      <td className="row-actions">
                        <button
                          type="button"
                          onClick={() => {
                            setError("");
                            setBarcodeCopies(1);
                            setProductForm({
                              ...emptyProduct,
                              ...product,
                              alias: product.alias || "",
                              category: product.category?._id || product.category,
                              wholesalePrice: product.wholesalePrice ?? "",
                              wholesaleMinQty: product.wholesaleMinQty ?? "",
                              costPrice: derivedCost(product.wholesalePrice ?? "", product.wholesaleMinQty ?? ""),
                              barcode: product.barcode || nextCode128Barcode(products),
                            });
                          }}
                        >
                          Edit
                        </button>
                        <button type="button" className="danger-text" onClick={() => removeProduct(product._id)}>
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <Pagination
            page={page}
            pages={pages}
            total={total}
            onChange={(next) => {
              loadProducts(next, query).catch((err) => setError(getErrorMessage(err, "Unable to load products.")));
            }}
          />
        </>
      ) : (
        <div className="table-wrap panel">
          <table>
            <thead>
              <tr>
                <th>Category</th>
                <th>Products</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {categories.map((item) => (
                <tr key={item._id}>
                  <td>
                    <strong>{item.name}</strong>
                    <small className="block">{item.description || "No description"}</small>
                  </td>
                  <td>{item.productCount}</td>
                  <td className="row-actions">
                    <button type="button" onClick={() => setCategoryForm(item)}>
                      Edit
                    </button>
                    <button type="button" className="danger-text" onClick={() => removeCategory(item._id)}>
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {productForm ? (
        <Modal title={productForm._id ? "Edit product" : "New product"} onClose={() => setProductForm(null)}>
          <form className="form-grid" onSubmit={saveProduct}>
            {error ? <div className="alert full">{error}</div> : null}
            <label>
              Name
              <input value={productForm.name} onChange={(event) => setProductForm({ ...productForm, name: event.target.value })} required />
            </label>
            <label>
              Alias
              <input
                value={productForm.alias}
                onChange={(event) => setProductForm({ ...productForm, alias: event.target.value })}
                placeholder="Optional"
              />
            </label>
            <div className="full">
              <span className="field-caption">Barcode</span>
              <div className="barcode-card">
                <Code128 value={productForm.barcode} name={productForm.name} price={productForm.retailPrice} />
              </div>
              <div className="barcode-print-row">
                <label className="barcode-copies">
                  Copies
                  <input
                    type="number"
                    min="1"
                    max="200"
                    value={barcodeCopies}
                    onChange={(event) => setBarcodeCopies(event.target.value)}
                  />
                </label>
                <button
                  type="button"
                  className="btn barcode-print-btn"
                  disabled={!productForm.barcode}
                  onClick={() =>
                    printBarcodeLabel({
                      name: productForm.name,
                      price: productForm.retailPrice,
                      barcode: productForm.barcode,
                      copies: barcodeCopies,
                    })
                  }
                >
                  Print barcode
                </button>
              </div>
            </div>
            <label>
              Category
              <select
                value={productForm.category}
                onChange={(event) => {
                  const category = event.target.value;
                  if (productForm._id) {
                    setProductForm({ ...productForm, category });
                    return;
                  }
                  const sku = nextSku(category, products, categories);
                  setProductForm({
                    ...productForm,
                    category,
                    sku,
                  });
                }}
                required
              >
                <option value="">Select category</option>
                {categories.map((item) => (
                  <option key={item._id} value={item._id}>
                    {item.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Unit
              <input value={productForm.unit} onChange={(event) => setProductForm({ ...productForm, unit: event.target.value })} />
            </label>
            <label>
              Stock
              <input type="number" min="0" value={productForm.stock} onChange={(event) => setProductForm({ ...productForm, stock: event.target.value })} />
            </label>
            <label>
              Retail price
              <input type="number" min="0" step="0.01" value={productForm.retailPrice} onChange={(event) => setProductForm({ ...productForm, retailPrice: event.target.value })} required />
            </label>
            <label>
              Wholesale price
              <input
                type="number"
                min="0"
                step="0.01"
                value={productForm.wholesalePrice}
                onChange={(event) => {
                  const wholesalePrice = event.target.value;
                  setProductForm({
                    ...productForm,
                    wholesalePrice,
                    costPrice: derivedCost(wholesalePrice, productForm.wholesaleMinQty),
                  });
                }}
                placeholder="Optional"
              />
            </label>
            <label>
              Wholesale min qty
              <input
                type="number"
                min="1"
                value={productForm.wholesaleMinQty}
                onChange={(event) => {
                  const wholesaleMinQty = event.target.value;
                  setProductForm({
                    ...productForm,
                    wholesaleMinQty,
                    costPrice: derivedCost(productForm.wholesalePrice, wholesaleMinQty),
                  });
                }}
                placeholder="Optional"
              />
            </label>
            <label>
              Cost
              <input type="number" min="0" step="0.01" value={productForm.costPrice} placeholder="Auto" disabled />
            </label>
            <label className="check">
              <input type="checkbox" checked={productForm.isActive} onChange={(event) => setProductForm({ ...productForm, isActive: event.target.checked })} />
              Active in POS
            </label>
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setProductForm(null)}>
                Cancel
              </button>
              <button type="submit" className="btn primary" disabled={saving}>
                {saving ? "Saving..." : "Save product"}
              </button>
            </div>
          </form>
        </Modal>
      ) : null}

      {categoryForm ? (
        <Modal title={categoryForm._id ? "Edit category" : "New category"} onClose={() => setCategoryForm(null)}>
          <form className="form-grid" onSubmit={saveCategory}>
            <label className="full">
              Name
              <input value={categoryForm.name} onChange={(event) => setCategoryForm({ ...categoryForm, name: event.target.value })} required />
            </label>
            <label className="full">
              Description
              <textarea rows="3" value={categoryForm.description || ""} onChange={(event) => setCategoryForm({ ...categoryForm, description: event.target.value })} />
            </label>
            <div className="modal-actions">
              <button type="button" className="btn" onClick={() => setCategoryForm(null)}>
                Cancel
              </button>
              <button type="submit" className="btn primary" disabled={saving}>
                {saving ? "Saving..." : "Save category"}
              </button>
            </div>
          </form>
        </Modal>
      ) : null}
    </section>
  );
}
