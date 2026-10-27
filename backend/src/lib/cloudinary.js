const cloudinary = require("cloudinary").v2;

function isConfigured() {
  return Boolean(
    process.env.CLOUDINARY_URL ||
      (process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET)
  );
}

function configure() {
  if (process.env.CLOUDINARY_URL) {
    cloudinary.config({ secure: true });
    return;
  }
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
  });
}

function requireCloudinary() {
  if (!isConfigured()) {
    const error = new Error(
      "Add CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET to backend/.env"
    );
    error.status = 500;
    throw error;
  }
  configure();
}

function uploadImage(file, folder) {
  requireCloudinary();
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: "image" },
      (error, result) => {
        if (error) return reject(error);
        resolve(result);
      }
    );
    stream.end(file.buffer);
  });
}

function uploadProductImage(file) {
  return uploadImage(file, process.env.CLOUDINARY_FOLDER || "ja-pos/products");
}

function uploadProfileImage(file) {
  return uploadImage(file, process.env.CLOUDINARY_PROFILE_FOLDER || "ja-pos/profile");
}

async function destroyImage(publicId) {
  if (!publicId || !isConfigured()) return;
  configure();
  await cloudinary.uploader.destroy(publicId);
}

module.exports = {
  isConfigured,
  uploadProductImage,
  uploadProfileImage,
  destroyImage,
  destroyProductImage: destroyImage,
};
