const express = require("express");
const User = require("../models/User");
const { protect, signToken, toUserResponse } = require("../middleware/auth");
const { handleImageUpload } = require("../lib/upload");
const { uploadProfileImage, destroyImage } = require("../lib/cloudinary");

const router = express.Router();

function sendSession(res, user) {
  const token = signToken(user);
  res.json({ token, user: toUserResponse(user) });
}

router.get("/staff", async (_req, res) => {
  try {
    const users = await User.find({
      isActive: true,
      role: { $ne: "SuperAdmin" },
      pincode: { $exists: true, $nin: [null, ""] },
    })
      .select("name")
      .sort({ name: 1 });
    res.json(users.map((user) => ({ id: user._id, name: user.name })));
  } catch (error) {
    res.status(500).json({ message: "Unable to load staff." });
  }
});

router.post("/login", async (req, res) => {
  try {
    const email = String(req.body.email || "").trim().toLowerCase();
    const password = String(req.body.password || "");

    if (!email || !password) {
      return res.status(400).json({ message: "Email/username and password are required." });
    }

    const user = await User.findOne({ email }).select("+password");
    if (!user || user.role !== "SuperAdmin" || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: "Invalid email/username or password." });
    }
    if (!user.isActive) {
      return res.status(401).json({ message: "This account is disabled." });
    }

    sendSession(res, user);
  } catch (error) {
    res.status(500).json({ message: "Unable to log in right now." });
  }
});

router.post("/pin-login", async (req, res) => {
  try {
    const userId = String(req.body.userId || "").trim();
    const pincode = String(req.body.pincode || "").trim();

    if (!userId || !/^\d{8}$/.test(pincode)) {
      return res.status(400).json({ message: "Select a staff member and enter an 8-digit PIN." });
    }

    const user = await User.findById(userId).select("+pincode");
    if (!user || user.role === "SuperAdmin" || !(await user.comparePincode(pincode))) {
      return res.status(401).json({ message: "Invalid PIN." });
    }
    if (!user.isActive) {
      return res.status(401).json({ message: "This account is disabled." });
    }

    sendSession(res, user);
  } catch (error) {
    res.status(500).json({ message: "Unable to log in right now." });
  }
});

router.get("/me", protect, (req, res) => {
  res.json({ user: toUserResponse(req.user) });
});

router.put("/profile", protect, handleImageUpload, async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const email = String(req.body.email || "").trim().toLowerCase();

    if (!name || !email) {
      return res.status(400).json({ message: "Name and email are required." });
    }

    const existing = await User.findOne({ email, _id: { $ne: req.user._id } });
    if (existing) {
      return res.status(400).json({ message: "That email is already in use." });
    }

    req.user.name = name;
    req.user.email = email;

    if (req.file) {
      if (req.user.avatarPublicId) await destroyImage(req.user.avatarPublicId);
      const result = await uploadProfileImage(req.file);
      req.user.avatarUrl = result.secure_url;
      req.user.avatarPublicId = result.public_id;
    } else if (String(req.body.removeImage) === "true") {
      if (req.user.avatarPublicId) await destroyImage(req.user.avatarPublicId);
      req.user.avatarUrl = "";
      req.user.avatarPublicId = "";
    }

    await req.user.save();

    res.json({ user: toUserResponse(req.user) });
  } catch (error) {
    res.status(error.status || 500).json({ message: error.message || "Unable to update profile." });
  }
});

router.put("/password", protect, async (req, res) => {
  try {
    const currentPassword = String(req.body.currentPassword || "");
    const newPassword = String(req.body.newPassword || "");

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: "Current and new passwords are required." });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: "New password must be at least 6 characters." });
    }

    const user = await User.findById(req.user._id).select("+password");
    if (!(await user.comparePassword(currentPassword))) {
      return res.status(400).json({ message: "Current password is incorrect." });
    }

    user.password = newPassword;
    await user.save();
    res.json({ message: "Password updated." });
  } catch (error) {
    res.status(500).json({ message: "Unable to update password." });
  }
});

module.exports = router;
