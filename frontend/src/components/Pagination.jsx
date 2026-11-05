export default function Pagination({ page, pages, total, onChange }) {
  if (pages <= 1) return null;
  return (
    <div className="pagination">
      <button type="button" className="btn" disabled={page <= 1} onClick={() => onChange(page - 1)}>
        Previous
      </button>
      <span>
        Page {page} of {pages}
        {typeof total === "number" ? ` · ${total} total` : ""}
      </span>
      <button type="button" className="btn" disabled={page >= pages} onClick={() => onChange(page + 1)}>
        Next
      </button>
    </div>
  );
}
