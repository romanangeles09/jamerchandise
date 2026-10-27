export function productImageSrc(product) {
  if (product?.imageUrl) return product.imageUrl;
  if (!product?._id || !product.hasImage) return "";
  const base = (import.meta.env.VITE_API_URL || "/api").replace(/\/$/, "");
  const stamp = product.updatedAt ? new Date(product.updatedAt).getTime() : Date.now();
  return `${base}/products/${product._id}/image?v=${stamp}`;
}
