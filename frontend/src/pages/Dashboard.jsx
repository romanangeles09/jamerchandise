import { useEffect, useState } from "react";
import { Package, ShoppingBag, Store, TriangleAlert, Wallet } from "lucide-react";
import api, { getErrorMessage } from "../lib/api";
import { formatDate, peso } from "../lib/money";

export default function Dashboard() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api
      .get("/dashboard")
      .then((res) => setData(res.data))
      .catch((err) => setError(getErrorMessage(err, "Unable to load dashboard.")));
  }, []);

  const maxRevenue = Math.max(1, ...(data?.weekly || []).map((day) => day.revenue));

  return (
    <section>
      <header className="page-head">
        <div>
          <span className="eyebrow">Today at the counter</span>
          <h1>Dashboard</h1>
        </div>
      </header>

      {error ? <div className="alert">{error}</div> : null}

      <div className="stat-grid">
        <article className="stat-card">
          <Wallet size={18} />
          <span>Today's sales</span>
          <strong>{peso(data?.today.revenue)}</strong>
          <small>
            {data?.today.sales || 0} {data?.today.sales === 1 ? "ticket" : "tickets"}
          </small>
        </article>
        <article className="stat-card">
          <Store size={18} />
          <span>Retail</span>
          <strong>{peso(data?.today.retail)}</strong>
          <small>Walk-in counter</small>
        </article>
        <article className="stat-card">
          <ShoppingBag size={18} />
          <span>Wholesale</span>
          <strong>{peso(data?.today.wholesale)}</strong>
          <small>Bulk orders</small>
        </article>
        <article className="stat-card">
          <Package size={18} />
          <span>Catalog</span>
          <strong>{data?.productCount || 0}</strong>
          <small>{data?.categoryCount || 0} categories</small>
        </article>
      </div>

      <div className="split">
        <article className="panel">
          <h2>Last 7 days</h2>
          <div className="bars">
            {(data?.weekly || []).map((day) => (
              <div key={day.date} className="bar-col">
                <div className="bar-track">
                  <div
                    className="bar-fill"
                    style={{ height: `${Math.max(6, (day.revenue / maxRevenue) * 100)}%` }}
                  />
                </div>
                <span>{day.label}</span>
              </div>
            ))}
          </div>
        </article>

        <article className="panel">
          <h2>
            <TriangleAlert size={16} /> Low stock
          </h2>
          {(data?.lowStock || []).length === 0 ? (
            <p className="empty">Stock levels look healthy.</p>
          ) : (
            <ul className="stack-list">
              {data.lowStock.map((product) => (
                <li key={product._id}>
                  <div>
                    <strong>{product.name}</strong>
                    <small>{product.category?.name}</small>
                  </div>
                  <em>
                    {product.stock} {product.unit}
                  </em>
                </li>
              ))}
            </ul>
          )}
        </article>
      </div>

      <article className="panel">
        <h2>Recent tickets</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Invoice</th>
                <th>Type</th>
                <th>Cashier</th>
                <th>When</th>
                <th>Total</th>
              </tr>
            </thead>
            <tbody>
              {(data?.recentSales || []).length === 0 ? (
                <tr>
                  <td colSpan={5} className="empty">
                    No sales yet. Open POS to start.
                  </td>
                </tr>
              ) : (
                data.recentSales.map((sale) => (
                  <tr key={sale._id}>
                    <td>{sale.invoiceNo}</td>
                    <td className="caps">{sale.saleType}</td>
                    <td>{sale.cashier?.name}</td>
                    <td>{formatDate(sale.createdAt)}</td>
                    <td>{peso(sale.total)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </article>
    </section>
  );
}
