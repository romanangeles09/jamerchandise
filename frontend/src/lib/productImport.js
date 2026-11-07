import * as XLSX from "xlsx";

function normalizeHeader(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ");
}

function pickColumn(headers, aliases) {
  for (const alias of aliases) {
    const index = headers.findIndex((header) => header === alias || header.includes(alias));
    if (index >= 0) return index;
  }
  return -1;
}

function cellText(value) {
  if (value == null) return "";
  return String(value).trim();
}

function parseNumber(value) {
  const cleaned = cellText(value).replace(/,/g, "").replace(/₱/g, "").replace(/php/gi, "").trim();
  if (!cleaned) return NaN;
  return Number(cleaned);
}

/** Parse .xlsx / .xls / .csv into import rows: { name, price, quantity }. */
export function parseProductImportFile(buffer) {
  const workbook = XLSX.read(buffer, { type: "array" });
  const sheetName = workbook.SheetNames[0];
  if (!sheetName) throw new Error("Excel file has no sheets.");

  const rows = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], {
    header: 1,
    defval: "",
    blankrows: false,
  });

  if (!rows.length) throw new Error("Excel file is empty.");

  const headers = rows[0].map(normalizeHeader);
  let nameIdx = pickColumn(headers, ["product name", "name", "item", "item name"]);
  let priceIdx = pickColumn(headers, ["retail price", "price", "amount"]);
  let qtyIdx = pickColumn(headers, ["quantity", "qty", "stock", "on hand"]);

  let dataStart = 1;
  // No header row: first row looks like data (name + numbers).
  if (nameIdx < 0 || priceIdx < 0 || qtyIdx < 0) {
    const first = rows[0];
    if (first.length >= 3 && cellText(first[0]) && Number.isFinite(parseNumber(first[1]))) {
      nameIdx = 0;
      priceIdx = 1;
      qtyIdx = 2;
      dataStart = 0;
    } else {
      throw new Error('Need columns: "Product Name", "Price", and "Quantity".');
    }
  }

  const items = [];
  const skipped = [];

  for (let i = dataStart; i < rows.length; i += 1) {
    const row = rows[i] || [];
    const name = cellText(row[nameIdx]);
    const price = parseNumber(row[priceIdx]);
    const quantity = parseNumber(row[qtyIdx]);
    const excelRow = i + 1;

    if (!name && !Number.isFinite(price) && !Number.isFinite(quantity)) continue;

    if (!name) {
      skipped.push(`Row ${excelRow}: missing product name.`);
      continue;
    }
    if (!Number.isFinite(price) || price < 0) {
      skipped.push(`Row ${excelRow}: invalid price.`);
      continue;
    }
    if (!Number.isFinite(quantity) || quantity < 0 || !Number.isInteger(quantity)) {
      skipped.push(`Row ${excelRow}: quantity must be a whole number.`);
      continue;
    }

    items.push({ name, price, quantity });
  }

  return { items, skipped };
}
