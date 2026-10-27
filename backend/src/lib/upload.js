const multer = require("multer");

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter(_req, file, cb) {
    if (!/^image\/(jpeg|png|webp|gif)$/i.test(file.mimetype)) {
      cb(new Error("Use a JPG, PNG, WEBP, or GIF image."));
      return;
    }
    cb(null, true);
  },
});

function handleImageUpload(req, res, next) {
  upload.single("image")(req, res, (err) => {
    if (!err) return next();
    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({ message: "Image must be 2 MB or smaller." });
    }
    return res.status(400).json({ message: err.message || "Unable to upload image." });
  });
}

module.exports = { handleImageUpload };
