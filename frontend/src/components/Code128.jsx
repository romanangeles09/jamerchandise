import { code128Svg } from "../lib/code128";

export default function Code128({ value }) {
  if (!value) return <span className="hint">Auto</span>;
  return <span className="barcode-svg" dangerouslySetInnerHTML={{ __html: code128Svg(value) }} />;
}
