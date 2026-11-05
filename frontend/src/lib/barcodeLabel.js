import { barcodeCaption, code128Svg } from "./code128";

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function printBarcodeLabel({ name, price, barcode, copies = 1 }) {
  const code = String(barcode || "").trim();
  if (!code) return;

  const count = Math.min(200, Math.max(1, Math.floor(Number(copies) || 1)));
  const caption = barcodeCaption(name, price);
  const svg = code128Svg(code, { height: 52, moduleWidth: 1.5, label: caption });
  const pages = Array.from(
    { length: count },
    () => `<div class="label"><div class="barcode">${svg}</div></div>`
  ).join("");
  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Barcode ${escapeHtml(code)}</title>
    <style>
      @page { size: 50mm 30mm; margin: 1.5mm; }
      html, body {
        margin: 0;
        padding: 0;
      }
      .label {
        box-sizing: border-box;
        width: 50mm;
        height: 30mm;
        padding: 1.5mm;
        page-break-after: always;
        break-after: page;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        font-family: Arial, Helvetica, sans-serif;
        color: #111;
        text-align: center;
      }
      .label:last-child {
        page-break-after: auto;
        break-after: auto;
      }
      .barcode { width: 46mm; }
      .barcode svg { width: 100%; height: auto; max-height: 24mm; }
    </style>
  </head>
  <body>
    ${pages}
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

  let cleaned = false;
  const cleanup = () => {
    if (cleaned) return;
    cleaned = true;
    frame.remove();
  };

  const runPrint = () => {
    try {
      frame.contentWindow.focus();
      frame.contentWindow.print();
    } catch (_) {
      cleanup();
    }
  };

  frame.contentWindow.addEventListener("afterprint", cleanup);
  // Keep the iframe alive long enough for multi-copy print jobs.
  setTimeout(cleanup, Math.max(15000, count * 1500));
  // Wait a tick so the iframe finishes layout before print.
  setTimeout(runPrint, 100);
}
