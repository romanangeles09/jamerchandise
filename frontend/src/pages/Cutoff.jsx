import { useEffect, useState } from "react";
import { Banknote, Package, Receipt, Wallet } from "lucide-react";
import api, { getErrorMessage } from "../lib/api";
import { formatDate, manilaToday, peso } from "../lib/money";
import { printReceipt, ReceiptActions } from "../lib/receipt";
import Modal from "../components/Modal";

export default function Cutoff() {
  const [date, setDate] = useState(manilaToday);
  const [payment, setPayment] = useState("all");
  const [cashier, setCashier] = useState("all");
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError("");
    api
      .get("/cutoff", { params: { date, payment, cashier } })
      .then((res) => {
        if (!cancelled) setData(res.data);
      })
      .catch((err) => {
        if (!cancelled) setError(getErrorMessage(err, "Unable to load cutoff."));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [date, payment, cashier]);

  const summary = data?.summary;

  return (
    <section>
      <header className="page-head">
        <div>
          <span className="eyebrow">Shift report</span>
          <h1>Cutoff</h1>
        </div>
        <strong>{peso(summary?.total)}</strong>
      </header>

      {error ? <div className="alert">{error}</div> : null}
      {loading ? <p className="hint">Loading cutoff...</p> : null}

      <div className="cutoff-filters">
        <label>
          Day
          <input type="date" value={date} onChange={(event) => setDate(event.target.value)} />
        </label>
        {data?.canPickCashier ? (
          <label>
            Cashier
            <select value={cashier} onChange={(event) => setCashier(event.target.value)}>
              <option value="all">All cashiers</option>
              {(data.cashiers || []).map((user) => (
                <option key={user.id} value={user.id}>
                  {user.name}
                </option>
              ))}
            </select>
          </label>
        ) : null}
        <div>
          <span className="block">Payment</span>
          <div className="segment cutoff-segment">
            {[
              ["all", "All"],
              ["cash", "Cash"],
              ["gcash", "GCash"],
            ].map(([value, label]) => (
              <button
                key={value}
                type="button"
                className={payment === value ? "active" : ""}
                onClick={() => setPayment(value)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="stat-grid cutoff-stats">
        <article className="stat-card">
          <Receipt size={18} />
          <span>Tickets</span>
          <strong>{summary?.tickets || 0}</strong>
          <small>{summary?.itemCount || 0} items sold</small>
        </article>
        <article className="stat-card">
          <Package size={18} />
          <span>Items sold</span>
          <strong>{summary?.itemCount || 0}</strong>
          <small>{peso(summary?.subtotal)} before discount</small>
        </article>
        <article className="stat-card">
          <Wallet size={18} />
          <span>Cash</span>
          <strong>{peso(summary?.cash)}</strong>
          <small>Cash payments</small>
        </article>
        <article className="stat-card">
          <Banknote size={18} />
          <span>GCash</span>
          <strong>{peso(summary?.gcash)}</strong>
          <small>GCash payments</small>
        </article>
      </div>

      <div className="split">
        <article className="panel">
          <h2>Products sold</h2>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Product</th>
                  <th>SKU</th>
                  <th>Qty</th>
                  <th>Amount</th>
                </tr>
              </thead>
              <tbody>
                {!data?.products?.length ? (
                  <tr>
                    <td colSpan={4} className="empty">
                      No product sales for this cutoff.
                    </td>
                  </tr>
                ) : (
                  data.products.map((product) => (
                    <tr key={product.sku}>
                      <td>
                        <strong>{product.name}</strong>
                      </td>
                      <td>{product.sku}</td>
                      <td>{product.qty}</td>
                      <td>{peso(product.amount)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </article>

        <article className="panel">
          <h2>Tickets</h2>
          <ul className="stack-list">
            {!data?.sales?.length ? (
              <li className="empty">No tickets for this cutoff.</li>
            ) : (
              data.sales.map((sale) => (
                <li key={sale._id}>
                  <button type="button" className="linkish" onClick={() => setSelected(sale)}>
                    <strong>{sale.invoiceNo}</strong>
                    <small>
                      {sale.cashier?.name || "—"} · {sale.paymentMethod} · {formatDate(sale.createdAt)}
                    </small>
                  </button>
                  <em>{peso(sale.total)}</em>
                </li>
              ))
            )}
          </ul>
          {summary?.discount ? (
            <p className="hint">Discounts: {peso(summary.discount)}</p>
          ) : null}
        </article>
      </div>

      {selected ? (
        <Modal title={`Ticket ${selected.invoiceNo}`} onClose={() => setSelected(null)}>
          <p className="caps">
            {selected.saleType} · {selected.paymentMethod}
            {selected.gcashTxnNo ? ` · ${selected.gcashTxnNo}` : ""} · {formatDate(selected.createdAt)}
          </p>
          <p className="hint">Cashier: {selected.cashier?.name || "—"}</p>
          <ul className="stack-list compact">
            {selected.items.map((item) => (
              <li key={`${item.sku}-${item.name}`}>
                <div>
                  <strong>
                    {item.qty} × {item.name}
                  </strong>
                  <small>
                    {item.sku} · {peso(item.unitPrice)}
                  </small>
                </div>
                <em>{peso(item.lineTotal)}</em>
              </li>
            ))}
          </ul>
          <dl className="totals">
            <div>
              <dt>Subtotal</dt>
              <dd>{peso(selected.subtotal)}</dd>
            </div>
            <div>
              <dt>Discount</dt>
              <dd>{peso(selected.discount)}</dd>
            </div>
            <div className="grand">
              <dt>Total</dt>
              <dd>{peso(selected.total)}</dd>
            </div>
            {String(selected.paymentMethod).toLowerCase() === "gcash" ? (
              <div>
                <dt>GCash Txn No.</dt>
                <dd>{selected.gcashTxnNo || "—"}</dd>
              </div>
            ) : null}
          </dl>
          <ReceiptActions onClose={() => setSelected(null)} onPrint={() => printReceipt(selected)} />
        </Modal>
      ) : null}
    </section>
  );
}
