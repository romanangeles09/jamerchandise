import { code128Svg } from "./code128";

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function printBarcodeLabel({ name, sku, barcode }) {
  const code = String(barcode || "").trim();
  if (!code) return;

  const svg = code128Svg(code, { height: 52, moduleWidth: 1.5 });
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
        width: 50mm;
        height: 30mm;
      }
      .label {
        width: 47mm;
        height: 27mm;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        font-family: Arial, Helvetica, sans-serif;
        color: #111;
        text-align: center;
      }
      .name {
        font-size: 9px;
        font-weight: 700;
        line-height: 1.1;
        max-width: 46mm;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      .barcode { width: 46mm; margin: 1mm 0 0; }
      .barcode svg { width: 100%; height: 16mm; }
      .sku {
        font-size: 8px;
        margin-top: 1mm;
      }
    </style>
  </head>
  <body>
    <div class="label">
      <div class="name">${escapeHtml(name || "JA Merchandise")}</div>
      <div class="barcode">${svg}</div>
      ${sku ? `<div class="sku">${escapeHtml(sku)}</div>` : ""}
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
