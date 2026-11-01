import { useEffect, useRef, useState } from "react";
import { Minus, Plus } from "lucide-react";
import { peso } from "../lib/money";

export default function BarcodeScanner({ error, cart, onScan, onUpdateQty, onClose }) {
  const inputRef = useRef(null);
  const onScanRef = useRef(onScan);
  const [manual, setManual] = useState("");

  onScanRef.current = onScan;

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    let buffer = "";
    let lastAt = 0;

    function onKeyDown(event) {
      const target = event.target;
      const inField = target === inputRef.current || target?.closest?.("input, textarea");
      if (inField) return;

      const now = Date.now();
      if (now - lastAt > 400) buffer = "";
      lastAt = now;

      if (event.key === "Enter") {
        const code = buffer.trim();
        buffer = "";
        if (!code) return;
        event.preventDefault();
        event.stopPropagation();
        onScanRef.current(code);
        return;
      }

      if (event.key === "Backspace") {
        if (!buffer) return;
        event.preventDefault();
        buffer = buffer.slice(0, -1);
        return;
      }

      if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
        event.preventDefault();
        event.stopPropagation();
        buffer += event.key;
      }
    }

    window.addEventListener("keydown", onKeyDown, true);
    return () => window.removeEventListener("keydown", onKeyDown, true);
  }, []);

  function submitManual(event) {
    event.preventDefault();
    const code = manual.trim();
    if (!code) return;
    onScan(code);
    setManual("");
    inputRef.current?.focus();
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal scanner-modal" onClick={(event) => event.stopPropagation()}>
        <div className="modal-head">
          <h3>Scan barcode</h3>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Close">
            ×
          </button>
        </div>

        <p className="hint">Scan with the USB barcode scanner, or type a barcode or SKU. Items appear below.</p>
        {error ? <p className="alert">{error}</p> : null}
        {cart?.length ? (
          <ul className="scan-cart">
            {cart.map((item) => (
              <li key={item.product}>
                <div>
                  <strong>{item.name}</strong>
                  <small>
                    {peso(item.unitPrice)} / {item.unit}
                  </small>
                </div>
                <div className="qty">
                  <button type="button" onClick={() => onUpdateQty(item.product, item.qty - 1)} aria-label="Decrease quantity">
                    <Minus size={14} />
                  </button>
                  <span>{item.qty}</span>
                  <button type="button" onClick={() => onUpdateQty(item.product, item.qty + 1)} aria-label="Increase quantity">
                    <Plus size={14} />
                  </button>
                </div>
              </li>
            ))}
          </ul>
        ) : (
          <p className="hint">Scanned items will show here.</p>
        )}

        <form className="scan-manual" onSubmit={submitManual}>
          <label>
            Barcode or SKU
            <input
              ref={inputRef}
              value={manual}
              onChange={(event) => setManual(event.target.value)}
              autoFocus
              autoComplete="off"
              spellCheck="false"
            />
          </label>
          <button type="submit" className="btn primary">
            Add
          </button>
        </form>

        <button type="button" className="btn full" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );
}
