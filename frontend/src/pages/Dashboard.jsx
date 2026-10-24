import { useEffect, useMemo, useState } from "react";
import { Package, ShoppingBag, Store, TriangleAlert, Wallet } from "lucide-react";
import api, { getErrorMessage } from "../lib/api";
import { formatDate, peso, weekdayShort } from "../lib/money";

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

export default function Dashboard() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api
      .get("/dashboard")
      .then((res) => setData(res.data))
      .catch((err) => setError(getErrorMessage(err, "Unable to load dashboard.")));
  }, []);

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
