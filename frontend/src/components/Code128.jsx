import { barcodeCaption, code128Svg } from "../lib/code128";

export default function Code128({ value, name = "", price = "" }) {
  if (!value) return <span className="hint">Auto</span>;
  const label = barcodeCaption(name, price);
  return <span className="barcode-svg" dangerouslySetInnerHTML={{ __html: code128Svg(value, { label }) }} />;
}
