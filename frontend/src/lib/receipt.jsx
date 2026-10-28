const STORE_NAME = "JA Merchandise";
const STORE_ADDRESS = "Bulakan, Bulacan";

function php(value) {
  const amount = Number(value) || 0;
  return `PHP ${amount.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function receiptDate(value) {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Manila",
    month: "2-digit",
    day: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
  }).format(new Date(value));
}

function line(label, amount) {
  return `<div class="row"><span>${escapeHtml(label)}</span><span>${escapeHtml(amount)}</span></div>`;
}

export function printReceipt(sale) {
  if (!sale) return;
  const pay = String(sale.paymentMethod || "cash").toUpperCase();
  const items = (sale.items || [])
    .map(
      (item) => `
        <div class="item">
          ${line(`${item.qty}X ${String(item.name || "").toUpperCase()}`, php(item.lineTotal))}
          <div class="muted">${escapeHtml(item.sku)}  ${php(item.unitPrice)}</div>
        </div>`
    )
    .join("");

  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>JA ${escapeHtml(sale.invoiceNo)}</title>
    <style>
      @page { size: 80mm auto; margin: 4mm; }
      body {
        margin: 0;
        font-family: "Courier New", Courier, monospace;
        font-size: 12px;
        color: #111;
      }
      .slip { width: 72mm; margin: 0 auto; }
      h1, h2, p { margin: 0; text-align: center; }
      h1 { font-size: 15px; letter-spacing: 0.4px; }
      h2 { font-size: 12px; font-weight: 400; margin-top: 2px; }
      .meta { margin: 10px 0 8px; }
      .row { display: flex; justify-content: space-between; gap: 8px; }
      .item { margin-bottom: 6px; }
      .muted { font-size: 11px; }
      .rule { text-align: center; margin: 8px 0; letter-spacing: 1px; }
      .foot { text-align: center; margin-top: 8px; }
      .foot p { margin-top: 4px; }
    </style>
  </head>
  <body>
    <div class="slip">
      <h1>${escapeHtml(STORE_NAME.toUpperCase())}</h1>
      <h2>${escapeHtml(STORE_ADDRESS)}</h2>
      <p class="meta"><strong>${escapeHtml(receiptDate(sale.createdAt))}</strong></p>
      ${line("TICKET:", sale.invoiceNo)}
      ${line("REGISTER:", "POS")}
      ${line("CASHIER:", String(sale.cashier?.name || "—").toUpperCase())}
      ${line("TYPE:", String(sale.saleType || "retail").toUpperCase())}
      <div class="rule">--------------------------------</div>
      ${items}
      <div class="rule">--------------------------------</div>
      ${line("SUBTOTAL:", php(sale.subtotal))}
      ${line("DISCOUNT:", php(sale.discount))}
      ${line("TOTAL:", php(sale.total))}
      <br />
      ${line(`${pay}:`, php(sale.amountPaid))}
      ${sale.paymentMethod === "gcash" && sale.gcashTxnNo ? line("GCASH TXN:", sale.gcashTxnNo) : ""}
      ${line("CHANGE:", php(sale.change))}
      <div class="rule">--------------------------------</div>
      <div class="foot">
        <p><strong>VISIT AGAIN SOON!</strong></p>
      </div>
    </div>
  </body>
</html>`;

  const frame = document.createElement("iframe");
  frame.setAttribute("aria-hidden", "true");
  frame.style.position = "fixed";
  frame.style.right = "0";
  frame.style.bottom = "0";
  frame.style.width = "0";
  frame.style.height = "0";
  frame.style.border = "0";
  document.body.appendChild(frame);
  const doc = frame.contentDocument;
  doc.open();
  doc.write(html);
  doc.close();
  const cleanup = () => frame.remove();
  frame.contentWindow.focus();
  frame.contentWindow.print();
  frame.contentWindow.addEventListener("afterprint", cleanup);
  setTimeout(cleanup, 2000);
}

export function ReceiptActions({ actionLabel = "Close", onClose, onPrint }) {
  return (
    <div className="ticket-actions">
      <button type="button" className="btn full" onClick={onPrint}>
        Print
      </button>
      <button type="button" className="btn primary full" onClick={onClose}>
        {actionLabel}
      </button>
    </div>
  );
}
