import { useEffect, useMemo, useState } from "react";
import api, { getErrorMessage } from "../lib/api";
import { formatDate, peso } from "../lib/money";
import Modal from "../components/Modal";

export default function Transactions() {
  const [sales, setSales] = useState([]);
  const [query, setQuery] = useState("");
  const [error, setError] = useState("");
  const [selected, setSelected] = useState(null);

  useEffect(() => {
    api
      .get("/sales", { params: { limit: 100 } })
      .then((res) => setSales(res.data))
      .catch((err) => setError(getErrorMessage(err, "Unable to load transactions.")));
  }, []);

  const filtered = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return sales;
    return sales.filter((sale) =>
      [sale.invoiceNo, sale.saleType, sale.paymentMethod, sale.cashier?.name]
        .join(" ")
        .toLowerCase()
        .includes(term)
    );
  }, [sales, query]);

  return (
    <section>
      <header className="page-head">
        <div>
          <span className="eyebrow">Sales history</span>
          <h1>Transactions</h1>
        </div>
      </header>

      {error ? <div className="alert">{error}</div> : null}

      <input
        className="search"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search invoice, type, payment, or cashier"
      />

      <div className="table-wrap panel">
        <table>
          <thead>
            <tr>
              <th>Invoice</th>
              <th>Type</th>
              <th>Payment</th>
              <th>Cashier</th>
              <th>When</th>
              <th>Total</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={7} className="empty">
                  No transactions yet.
                </td>
              </tr>
            ) : (
              filtered.map((sale) => (
                <tr key={sale._id}>
                  <td>
                    <strong>{sale.invoiceNo}</strong>
                  </td>
                  <td className="caps">{sale.saleType}</td>
                  <td className="caps">{sale.paymentMethod}</td>
                  <td>{sale.cashier?.name}</td>
                  <td>{formatDate(sale.createdAt)}</td>
                  <td>{peso(sale.total)}</td>
                  <td className="row-actions">
                    <button type="button" onClick={() => setSelected(sale)}>
                      View
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {selected ? (
        <Modal title={`Ticket ${selected.invoiceNo}`} onClose={() => setSelected(null)}>
          <p className="caps">
            {selected.saleType} · {selected.paymentMethod} · {formatDate(selected.createdAt)}
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
            <div>
              <dt>Paid</dt>
              <dd>{peso(selected.amountPaid)}</dd>
            </div>
            <div>
              <dt>Change</dt>
              <dd>{peso(selected.change)}</dd>
            </div>
          </dl>
          <button type="button" className="btn primary full" onClick={() => setSelected(null)}>
            Close
          </button>
        </Modal>
      ) : null}
    </section>
  );
}
