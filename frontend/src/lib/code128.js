const PATTERNS = [
  "11011001100", "11001101100", "11001100110", "10010011000", "10010001100",
  "10001001100", "10011001000", "10011000100", "10001100100", "11001001000",
  "11001000100", "11000100100", "10110011100", "10011011100", "10011001110",
  "10111001100", "10011101100", "10011100110", "11001110010", "11001011100",
  "11001001110", "11011100100", "11001110100", "11101101110", "11101001100",
  "11100101100", "11100100110", "11101100100", "11100110100", "11100110010",
  "11011011000", "11011000110", "11000110110", "10100011000", "10001011000",
  "10001000110", "10110001000", "10001101000", "10001100010", "11010001000",
  "11000101000", "11000100010", "10110111000", "10110001110", "10001101110",
  "10111011000", "10111000110", "10001110110", "11101110110", "11010001110",
  "11000101110", "11011101000", "11011100010", "11011101110", "11101011000",
  "11101000110", "11100010110", "11101101000", "11101100010", "11100011010",
  "11101111010", "11001000010", "11110001010", "10100110000", "10100001100",
  "10010110000", "10010000110", "10000101100", "10000100110", "10110010000",
  "10110000100", "10011010000", "10011000010", "10000110100", "10000110010",
  "11000010010", "11001010000", "11110111010", "11000010100", "10001111010",
  "10100111100", "10010111100", "10010011110", "10111100100", "10011110100",
  "10011110010", "11110100100", "11110010100", "11110010010", "11011011110",
  "11011110110", "11110110110", "10101111000", "10100011110", "10001011110",
  "10111101000", "10111100010", "11110101000", "11110100010", "10111011110",
  "10111101110", "11101011110", "11110101110", "11010000100", "11010010000",
  "11010011100", "11000111010",
];

export function generateCode128Value() {
  return `${Math.floor(Math.random() * 9) + 1}${Array.from({ length: 12 }, () => Math.floor(Math.random() * 10)).join("")}`;
}

export function nextCode128Barcode(products = []) {
  const used = new Set(products.map((product) => String(product.barcode || "")));
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const code = generateCode128Value();
    if (!used.has(code)) return code;
  }
  return Date.now().toString().padStart(13, "0").slice(-13);
}

export function code128Bits(value) {
  const text = String(value || "");
  if (!text) return "";
  const start = 104;
  const codes = [start];
  let checksum = start;
  for (let i = 0; i < text.length; i += 1) {
    const code = text.charCodeAt(i) - 32;
    if (code < 0 || code > 94) return "";
    codes.push(code);
    checksum += code * (i + 1);
  }
  codes.push(checksum % 103);
  codes.push(106);
  return `${codes.map((code) => PATTERNS[code]).join("")}11`;
}

function escapeSvgText(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function barcodeCaption(name, price) {
  const title = String(name || "").trim() || "JA Merchandise";
  const amount = Number(price);
  if (!Number.isFinite(amount) || String(price ?? "").trim() === "") return title;
  const priceText = Number.isInteger(amount) ? String(amount) : amount.toFixed(2);
  return `${title} Php ${priceText}`;
}

export function code128Svg(value, { height = 64, moduleWidth = 2, label } = {}) {
  const bits = code128Bits(value);
  if (!bits) return "";
  const width = bits.length * moduleWidth;
  let x = 0;
  let bars = "";
  for (const bit of bits) {
    if (bit === "1") {
      bars += `<rect x="${x}" y="0" width="${moduleWidth}" height="${height}" />`;
    }
    x += moduleWidth;
  }
  const caption = label == null ? value : label;
  const labelY = height + 18;
  return `<svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Barcode ${escapeSvgText(value)}" viewBox="0 0 ${width} ${labelY + 4}" width="${width}" height="${labelY + 4}">
    <rect width="${width}" height="${labelY + 4}" fill="#fff" />
    <g fill="#12211b">${bars}</g>
    <text x="${width / 2}" y="${labelY}" text-anchor="middle" font-size="13" font-family="ui-sans-serif, system-ui, Arial, sans-serif" fill="#12211b">${escapeSvgText(caption)}</text>
  </svg>`;
}
