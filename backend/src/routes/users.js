const express = require("express");
const User = require("../models/User");
const { ACCESS_PAGES, allAccess } = require("../lib/access");
const { protect, requireAccess, toUserResponse } = require("../middleware/auth");

const router = express.Router();
router.use(protect, requireAccess("users"));

function cleanAccess(list, role) {
  if (role === "SuperAdmin") return allAccess();
  const selected = Array.isArray(list) ? list.filter((page) => ACCESS_PAGES.includes(page)) : [];
  return selected.length ? selected : ["account"];
}

function cleanRole(role, actor) {
  if (role === "SuperAdmin" && actor.role !== "SuperAdmin") return "Cashier";
  return ["SuperAdmin", "Admin", "Cashier"].includes(role) ? role : "Cashier";
}

router.get("/", async (_req, res) => {
  try {
    const users = await User.find().sort({ createdAt: 1 });
    res.json(users.map((user) => toUserResponse(user)));
  } catch (error) {
    res.status(500).json({ message: "Unable to load users." });
  }
});

router.post("/", async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const email = String(req.body.email || "").trim().toLowerCase();
    const password = String(req.body.password || "");
    const role = cleanRole(req.body.role, req.user);
    const access = cleanAccess(req.body.access, role);

    if (!name) return res.status(400).json({ message: "Name is required." });
    if (!email) return res.status(400).json({ message: "Email or username is required." });
    if (password.length < 6) return res.status(400).json({ message: "Password must be at least 6 characters." });

    const user = await User.create({ name, email, password, role, access, isActive: true });
    res.status(201).json(toUserResponse(user));
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "That email or username is already in use." });
    }
    res.status(500).json({ message: "Unable to create user." });
  }
});

router.put("/:id", async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select("+password");
    if (!user) return res.status(404).json({ message: "User not found." });
    if (user.role === "SuperAdmin" && req.user.role !== "SuperAdmin") {
      return res.status(403).json({ message: "Only SuperAdmin can edit a SuperAdmin account." });
    }

    const name = String(req.body.name || "").trim();
    const email = String(req.body.email || "").trim().toLowerCase();
    if (!name || !email) {
      return res.status(400).json({ message: "Name and email or username are required." });
    }

    const existing = await User.findOne({ email, _id: { $ne: user._id } });
    if (existing) {
      return res.status(400).json({ message: "That email or username is already in use." });
    }

    user.name = name;
    user.email = email;
    if (user.role !== "SuperAdmin" || req.user.role === "SuperAdmin") {
      user.role = cleanRole(req.body.role, req.user);
      user.access = cleanAccess(req.body.access, user.role);
    }
    if (req.body.isActive === false && String(user._id) === String(req.user._id)) {
      return res.status(400).json({ message: "You cannot disable your own account." });
    }
    if (typeof req.body.isActive === "boolean") user.isActive = req.body.isActive;

    const password = String(req.body.password || "");
    if (password) {
      if (password.length < 6) {
        return res.status(400).json({ message: "Password must be at least 6 characters." });
      }
      user.password = password;
    }

    await user.save();
    res.json(toUserResponse(user));
  } catch (error) {
    res.status(500).json({ message: "Unable to update user." });
  }
});

router.delete("/:id", async (req, res) => {
  try {
    if (String(req.params.id) === String(req.user._id)) {
      return res.status(400).json({ message: "You cannot delete your own account." });
    }
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: "User not found." });
    if (user.role === "SuperAdmin") {
      return res.status(400).json({ message: "SuperAdmin accounts cannot be deleted." });
    }
    await user.deleteOne();
    res.json({ message: "User deleted." });
  } catch (error) {
    res.status(500).json({ message: "Unable to delete user." });
  }
});

module.exports = { router };
