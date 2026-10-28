import { useEffect, useRef, useState } from "react";
import { Minus, Plus } from "lucide-react";
import { peso } from "../lib/money";

export default function BarcodeScanner({ error, cart, onScan, onUpdateQty, onClose }) {
  const videoRef = useRef(null);
  const onScanRef = useRef(onScan);
  const [manual, setManual] = useState("");
  const [cameraError, setCameraError] = useState("");

  onScanRef.current = onScan;

  useEffect(() => {
    const video = videoRef.current;
    let stream;
    let timer;
    let cancelled = false;
    const last = { code: "", at: 0 };

    async function start() {
      try {
        if (!navigator.mediaDevices?.getUserMedia) {
          throw new Error("no camera");
        }

        stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: "environment" } },
          audio: false,
        });
        if (cancelled) {
          stream.getTracks().forEach((track) => track.stop());
          return;
        }

        video.srcObject = stream;
        await video.play();

        if (typeof window.BarcodeDetector !== "function") {
          setCameraError("Live camera scan is not supported in this browser. Type the barcode below.");
          return;
        }

        const detector = new window.BarcodeDetector({
          formats: ["ean_13", "ean_8", "code_128", "code_39", "upc_a", "upc_e", "codabar", "itf", "qr_code"],
        });

        const tick = async () => {
          if (cancelled) return;
          try {
            if (video.readyState >= 2) {
              const codes = await detector.detect(video);
              const value = String(codes[0]?.rawValue || "").trim();
              if (value) {
                const now = Date.now();
                if (value !== last.code || now - last.at > 1600) {
                  last.code = value;
                  last.at = now;
                  onScanRef.current(value);
                }
              }
            }
          } catch (_error) {
            // Keep the scanner running if a frame fails to decode.
          }
          timer = window.setTimeout(tick, 250);
        };

        tick();
      } catch (_error) {
        if (!cancelled) {
          setCameraError("Camera is not available. Type the barcode below.");
        }
      }
    }

    start();

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
      if (stream) stream.getTracks().forEach((track) => track.stop());
      if (video) video.srcObject = null;
    };
  }, []);

  function submitManual(event) {
    event.preventDefault();
    const code = manual.trim();
    if (!code) return;
    onScan(code);
    setManual("");
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

        <video ref={videoRef} className="barcode-video" playsInline muted autoPlay />
        {cameraError ? (
          <p className="hint">{cameraError}</p>
        ) : (
          <p className="hint">Point the camera at a barcode. Keep scanning to add more items.</p>
        )}
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
              value={manual}
              onChange={(event) => setManual(event.target.value)}
              autoFocus
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
