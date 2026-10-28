import { useEffect, useMemo, useState } from "react";
import api, { getErrorMessage } from "../lib/api";
import { productImageSrc } from "../lib/image";
import { peso } from "../lib/money";
import Modal from "../components/Modal";

const emptyProduct = {
  name: "",
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
  imageFile: null,
  previewUrl: "",
  removeImage: false,
  skuManual: false,
  costManual: false,
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

export default function Inventory() {
  const [tab, setTab] = useState("products");
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [query, setQuery] = useState("");
  const [error, setError] = useState("");
  const [productForm, setProductForm] = useState(null);
  const [categoryForm, setCategoryForm] = useState(null);
  const [saving, setSaving] = useState(false);

  async function load() {
    const [productRes, categoryRes] = await Promise.all([api.get("/products"), api.get("/categories")]);
    setProducts(productRes.data);
    setCategories(categoryRes.data);
  }

  useEffect(() => {
    load().catch((err) => setError(getErrorMessage(err, "Unable to load inventory.")));
  }, []);

  const filteredProducts = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return products;
    return products.filter(
      (product) =>
        product.name.toLowerCase().includes(term) ||
        product.sku.toLowerCase().includes(term) ||
        product.category?.name.toLowerCase().includes(term)
    );
  }, [products, query]);

  async function saveProduct(event) {
    event.preventDefault();
    setSaving(true);
    setError("");
    try {
      const form = new FormData();
      form.append("name", productForm.name);
      form.append("sku", productForm.sku);
      form.append("barcode", productForm.barcode || "");
      form.append("category", productForm.category);
      form.append("unit", productForm.unit || "pc");
      form.append("retailPrice", String(Number(productForm.retailPrice)));
      form.append("wholesalePrice", productForm.wholesalePrice === "" || productForm.wholesalePrice == null ? "" : String(Number(productForm.wholesalePrice)));
      form.append("wholesaleMinQty", productForm.wholesaleMinQty === "" || productForm.wholesaleMinQty == null ? "" : String(Number(productForm.wholesaleMinQty)));
      form.append("costPrice", productForm.costPrice === "" || productForm.costPrice == null ? "" : String(Number(productForm.costPrice)));
      form.append("stock", String(Number(productForm.stock || 0)));
      form.append("reorderLevel", String(Number(productForm.reorderLevel || 10)));
      form.append("isActive", productForm.isActive !== false ? "true" : "false");
      if (productForm.imageFile) form.append("image", productForm.imageFile);
      if (productForm.removeImage) form.append("removeImage", "true");
      if (productForm._id) {
        await api.put(`/products/${productForm._id}`, form);
      } else {
        await api.post("/products", form);
      }
      setProductForm(null);
      await load();
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
    await load();
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
                setProductForm({
                  ...emptyProduct,
                  category,
                  sku: nextSku(category, products, categories),
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
                  <th />
                  <th>Product</th>
                  <th>Category</th>
                  <th>Retail</th>
                  <th>Wholesale</th>
                  <th>Stock</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {filteredProducts.map((product) => (
                  <tr key={product._id}>
                    <td className="thumb-cell">
                      {product.hasImage ? (
                        <img src={productImageSrc(product)} alt="" className="product-thumb" />
                      ) : (
                        <span className="product-thumb placeholder">{product.name.slice(0, 1)}</span>
                      )}
                    </td>
                    <td>
                      <strong>{product.name}</strong>
                      <small className="block">{product.sku}</small>
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
                          setProductForm({
                            ...emptyProduct,
                            ...product,
                            category: product.category?._id || product.category,
                            wholesalePrice: product.wholesalePrice ?? "",
                            wholesaleMinQty: product.wholesaleMinQty ?? "",
                            costPrice: product.costPrice ?? "",
                            imageFile: null,
                            previewUrl: productImageSrc(product),
                            removeImage: false,
                            skuManual: true,
                            costManual: product.costPrice != null && product.costPrice !== "",
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
                ))}
              </tbody>
            </table>
          </div>
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
            <label className="full">
              Product image
              <div className="image-picker">
                {productForm.previewUrl && !productForm.removeImage ? (
                  <img src={productForm.previewUrl} alt="" className="image-preview" />
                ) : (
                  <span className="image-preview placeholder">No photo</span>
                )}
                <div>
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif"
                    onChange={(event) => {
                      const file = event.target.files?.[0];
                      if (!file) return;
                      setProductForm({
                        ...productForm,
                        imageFile: file,
                        previewUrl: URL.createObjectURL(file),
                        removeImage: false,
                      });
                    }}
                  />
                  <small className="hint">JPG, PNG, WEBP, or GIF up to 2 MB.</small>
                  {productForm.previewUrl && !productForm.removeImage ? (
                    <button
                      type="button"
                      className="danger-text"
                      onClick={() =>
                        setProductForm({
                          ...productForm,
                          imageFile: null,
                          previewUrl: "",
                          removeImage: true,
                        })
                      }
                    >
                      Remove photo
                    </button>
                  ) : null}
                </div>
              </div>
            </label>
            <label>
              Name
              <input value={productForm.name} onChange={(event) => setProductForm({ ...productForm, name: event.target.value })} required />
            </label>
            <label>
              SKU
              <input
                value={productForm.sku}
                placeholder="Auto"
                onChange={(event) => {
                  const sku = event.target.value;
                  setProductForm({
                    ...productForm,
                    sku: sku.trim() ? sku : nextSku(productForm.category, products, categories),
                    skuManual: Boolean(sku.trim()),
                  });
                }}
              />
            </label>
            <label>
              Barcode
              <input value={productForm.barcode} onChange={(event) => setProductForm({ ...productForm, barcode: event.target.value })} />
            </label>
            <label>
              Category
              <select
                value={productForm.category}
                onChange={(event) => {
                  const category = event.target.value;
                  setProductForm({
                    ...productForm,
                    category,
                    sku: productForm.skuManual ? productForm.sku : nextSku(category, products, categories),
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
                    costPrice: productForm.costManual
                      ? productForm.costPrice
                      : derivedCost(wholesalePrice, productForm.wholesaleMinQty),
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
                    costPrice: productForm.costManual
                      ? productForm.costPrice
                      : derivedCost(productForm.wholesalePrice, wholesaleMinQty),
                  });
                }}
                placeholder="Optional"
              />
            </label>
            <label>
              Cost
              <input
                type="number"
                min="0"
                step="0.01"
                value={productForm.costPrice}
                onChange={(event) => {
                  const costPrice = event.target.value;
                  setProductForm({
                    ...productForm,
                    costPrice: costPrice.trim() ? costPrice : derivedCost(productForm.wholesalePrice, productForm.wholesaleMinQty),
                    costManual: Boolean(costPrice.trim()),
                  });
                }}
                placeholder="Auto"
              />
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
