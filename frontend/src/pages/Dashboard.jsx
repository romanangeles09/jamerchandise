import { useEffect, useMemo, useState } from "react";
import { Package, ShoppingBag, Store, TriangleAlert, Wallet } from "lucide-react";
import api, { getErrorMessage } from "../lib/api";
import { formatDate, manilaYear, peso, weekdayShort } from "../lib/money";
import Modal from "../components/Modal";

function niceCeil(value) {
  if (value <= 0) return 100;
  const pow = 10 ** Math.floor(Math.log10(value));
  const n = value / pow;
  const nice = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10;
  return nice * pow;
}

function axisLabel(value) {
  if (value >= 1000) {
    const thousands = value / 1000;
    return `₱${Number.isInteger(thousands) ? thousands : thousands.toFixed(1)}k`;
  }
  return `₱${Math.round(value)}`;
}

function WeeklyGraph({ weekly }) {
  const days = weekly?.length ? weekly : [];
  const chart = useMemo(() => {
    const width = 700;
    const height = 210;
    const pad = { top: 10, bottom: 8 };
    const innerH = height - pad.top - pad.bottom;
    const yMax = niceCeil(Math.max(0, ...days.map((day) => day.revenue)));
    const ticks = [0, 0.25, 0.5, 0.75, 1].map((ratio) => ({
      ratio,
      value: yMax * ratio,
      y: pad.top + innerH * (1 - ratio),
    }));
    const points = days.map((day, index) => {
      const x = ((index + 0.5) / days.length) * width;
      const y = pad.top + innerH - (day.revenue / Math.max(yMax, 1)) * innerH;
      return { ...day, x, y };
    });
    const line = points.map((point, index) => `${index === 0 ? "M" : "L"}${point.x},${point.y}`).join(" ");
    const area = points.length
      ? `${line} L${points[points.length - 1].x},${pad.top + innerH} L${points[0].x},${pad.top + innerH} Z`
      : "";
    return { width, height, pad, innerH, ticks, points, line, area, yMax };
  }, [days]);

  if (!days.length) return <p className="empty">No sales data yet.</p>;

  return (
    <div className="graph">
      <div className="graph-y">
        {[...chart.ticks].reverse().map((tick) => (
          <span key={tick.ratio}>{axisLabel(tick.value)}</span>
        ))}
      </div>
      <div className="graph-plot">
        <svg
          viewBox={`0 0 ${chart.width} ${chart.height}`}
          preserveAspectRatio="none"
          role="img"
          aria-label="Sales for the last 7 days"
        >
          {chart.ticks.map((tick) => (
            <line
              key={tick.ratio}
              x1="0"
              x2={chart.width}
              y1={tick.y}
              y2={tick.y}
              className="graph-grid"
            />
          ))}
          <path d={chart.area} className="graph-area" />
          <path d={chart.line} className="graph-line" />
          {chart.points.map((point) => (
            <g key={point.date}>
              <circle cx={point.x} cy={point.y} r="4.5" className="graph-dot" />
              <title>{`${weekdayShort(point.date)}: ${peso(point.revenue)}`}</title>
            </g>
          ))}
        </svg>
        <div className="graph-x">
          {days.map((day) => (
            <span key={day.date}>{weekdayShort(day.date)}</span>
          ))}
        </div>
      </div>
    </div>
  );
}

function MonthlyGraph({ monthly, year, onSelectMonth }) {
  const months = monthly?.length ? monthly : [];
  const currentMonth =
    year === manilaYear()
      ? Number(new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Manila", month: "2-digit" }).format(new Date()))
      : 0;
  const chart = useMemo(() => {
    const width = 840;
    const height = 240;
    const pad = { top: 10, bottom: 8 };
    const innerH = height - pad.top - pad.bottom;
    const yMax = niceCeil(Math.max(0, ...months.map((month) => month.revenue)));
    const ticks = [0, 0.25, 0.5, 0.75, 1].map((ratio) => ({
      ratio,
      value: yMax * ratio,
      y: pad.top + innerH * (1 - ratio),
    }));
    const slot = width / Math.max(months.length, 12);
    const barWidth = slot * 0.55;
    const bars = months.map((month, index) => {
      const barHeight = (month.revenue / Math.max(yMax, 1)) * innerH;
      return {
        ...month,
        slotX: slot * index,
        slotWidth: slot,
        x: slot * index + (slot - barWidth) / 2,
        y: pad.top + innerH - barHeight,
        width: barWidth,
        height: barHeight,
        current: month.month === currentMonth,
      };
    });
    return { width, height, pad, innerH, ticks, bars, yMax };
  }, [months, currentMonth]);

  if (!months.length) return <p className="empty">No monthly sales yet.</p>;

  return (
    <div className="graph monthly">
      <div className="graph-y">
        {[...chart.ticks].reverse().map((tick) => (
          <span key={tick.ratio}>{axisLabel(tick.value)}</span>
        ))}
      </div>
      <div className="graph-plot">
        <svg
          viewBox={`0 0 ${chart.width} ${chart.height}`}
          preserveAspectRatio="none"
          role="img"
          aria-label={`Monthly sales for ${year}`}
        >
          {chart.ticks.map((tick) => (
            <line
              key={tick.ratio}
              x1="0"
              x2={chart.width}
              y1={tick.y}
              y2={tick.y}
              className="graph-grid"
            />
          ))}
          {chart.bars.map((bar) => (
            <g
              key={bar.month}
              className="graph-bar-group"
              role="button"
              tabIndex={0}
              aria-label={`${bar.label} ${year}: ${peso(bar.revenue)}`}
              onClick={() => onSelectMonth?.(bar)}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ") {
                  event.preventDefault();
                  onSelectMonth?.(bar);
                }
              }}
            >
              <rect x={bar.slotX} y="0" width={bar.slotWidth} height={chart.height} className="graph-hit" />
              <rect
                x={bar.x}
                y={bar.y}
                width={bar.width}
                height={Math.max(bar.height, bar.revenue > 0 ? 2 : 0)}
                rx="4"
                className={bar.current ? "graph-bar current" : "graph-bar"}
              />
              <title>{`${bar.label} ${year}: ${peso(bar.revenue)} · ${bar.sales} ${bar.sales === 1 ? "ticket" : "tickets"}`}</title>
            </g>
          ))}
        </svg>
        <div className="graph-x months">
          {months.map((month) => (
            <button key={month.month} type="button" className="month-label" onClick={() => onSelectMonth?.(month)}>
              {month.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function Dashboard() {
  const [data, setData] = useState(null);
  const [year, setYear] = useState(manilaYear);
  const [error, setError] = useState("");
  const [monthDetail, setMonthDetail] = useState(null);
  const [monthLoading, setMonthLoading] = useState(false);
  const [selectedTicket, setSelectedTicket] = useState(null);

  useEffect(() => {
    api
      .get("/dashboard", { params: { year } })
      .then((res) => {
        setData(res.data);
        if (res.data.year) setYear(res.data.year);
      })
      .catch((err) => setError(getErrorMessage(err, "Unable to load dashboard.")));
  }, [year]);

  async function openMonth(month) {
    setSelectedTicket(null);
    setMonthLoading(true);
    setMonthDetail({ year, month: month.month, label: month.label });
    try {
      const res = await api.get("/dashboard/month", { params: { year, month: month.month } });
      setMonthDetail(res.data);
    } catch (err) {
      setError(getErrorMessage(err, "Unable to load month details."));
      setMonthDetail(null);
    } finally {
      setMonthLoading(false);
    }
  }

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
          <WeeklyGraph weekly={data?.weekly || []} />
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

      <article className="panel monthly-panel">
        <div className="panel-head">
          <h2>Monthly sales</h2>
          <label className="year-filter">
            Year
            <select value={year} onChange={(event) => setYear(Number(event.target.value))}>
              {(data?.years || [year]).map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </label>
        </div>
        <MonthlyGraph monthly={data?.monthly || []} year={year} onSelectMonth={openMonth} />
      </article>

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

      {monthDetail ? (
        <Modal
          wide
          title={`${monthDetail.label || ""} ${monthDetail.year || year}`}
          onClose={() => {
            setMonthDetail(null);
            setSelectedTicket(null);
          }}
        >
          <div className="month-modal">
            {monthLoading && !monthDetail.summary ? <p className="hint">Loading month details...</p> : null}
            {monthDetail.summary ? (
              <>
                <div className="month-stats">
                  <div>
                    <span>Total</span>
                    <strong>{peso(monthDetail.summary.total)}</strong>
                  </div>
                  <div>
                    <span>Tickets</span>
                    <strong>{monthDetail.summary.tickets}</strong>
                  </div>
                  <div>
                    <span>Items</span>
                    <strong>{monthDetail.summary.itemCount}</strong>
                  </div>
                  <div>
                    <span>Discount</span>
                    <strong>{peso(monthDetail.summary.discount)}</strong>
                  </div>
                  <div>
                    <span>Cash</span>
                    <strong>{peso(monthDetail.summary.cash)}</strong>
                  </div>
                  <div>
                    <span>GCash</span>
                    <strong>{peso(monthDetail.summary.gcash)}</strong>
                  </div>
                  <div>
                    <span>Retail</span>
                    <strong>{peso(monthDetail.summary.retail)}</strong>
                  </div>
                  <div>
                    <span>Wholesale</span>
                    <strong>{peso(monthDetail.summary.wholesale)}</strong>
                  </div>
                </div>

                {monthDetail.cashiers?.length > 1 ? (
                  <>
                    <h4>By cashier</h4>
                    <div className="table-wrap">
                      <table>
                        <thead>
                          <tr>
                            <th>Cashier</th>
                            <th>Tickets</th>
                            <th>Amount</th>
                          </tr>
                        </thead>
                        <tbody>
                          {monthDetail.cashiers.map((row) => (
                            <tr key={row.name}>
                              <td>{row.name}</td>
                              <td>{row.tickets}</td>
                              <td>{peso(row.total)}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </>
                ) : null}

                <h4>Products sold</h4>
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
                      {!monthDetail.products?.length ? (
                        <tr>
                          <td colSpan={4} className="empty">
                            No product sales this month.
                          </td>
                        </tr>
                      ) : (
                        monthDetail.products.map((product) => (
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

                <h4>Tickets</h4>
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Invoice</th>
                        <th>Type</th>
                        <th>Payment</th>
                        <th>Cashier</th>
                        <th>When</th>
                        <th>Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {!monthDetail.sales?.length ? (
                        <tr>
                          <td colSpan={6} className="empty">
                            No tickets this month.
                          </td>
                        </tr>
                      ) : (
                        monthDetail.sales.map((sale) => (
                          <tr key={sale._id}>
                            <td>
                              <button type="button" className="linkish" onClick={() => setSelectedTicket(sale)}>
                                <strong>{sale.invoiceNo}</strong>
                              </button>
                            </td>
                            <td className="caps">{sale.saleType}</td>
                            <td className="caps">{sale.paymentMethod}</td>
                            <td>{sale.cashier?.name}</td>
                            <td>{formatDate(sale.createdAt)}</td>
                            <td>{peso(sale.total)}</td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </>
            ) : null}
            <button
              type="button"
              className="btn primary full"
              onClick={() => {
                setMonthDetail(null);
                setSelectedTicket(null);
              }}
            >
              Close
            </button>
          </div>
        </Modal>
      ) : null}

      {selectedTicket ? (
        <Modal title={`Ticket ${selectedTicket.invoiceNo}`} onClose={() => setSelectedTicket(null)}>
          <p className="caps">
            {selectedTicket.saleType} · {selectedTicket.paymentMethod} · {formatDate(selectedTicket.createdAt)}
          </p>
          <p className="hint">Cashier: {selectedTicket.cashier?.name || "—"}</p>
          <ul className="stack-list compact">
            {selectedTicket.items.map((item) => (
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
              <dd>{peso(selectedTicket.subtotal)}</dd>
            </div>
            <div>
              <dt>Discount</dt>
              <dd>{peso(selectedTicket.discount)}</dd>
            </div>
            <div className="grand">
              <dt>Total</dt>
              <dd>{peso(selectedTicket.total)}</dd>
            </div>
          </dl>
          <button type="button" className="btn primary full" onClick={() => setSelectedTicket(null)}>
            Back to month
          </button>
        </Modal>
      ) : null}
    </section>
  );
}
