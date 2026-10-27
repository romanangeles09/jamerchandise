const jwt = require("jsonwebtoken");
const User = require("../models/User");
const { hasAccess, resolveAccess } = require("../lib/access");

async function protect(req, res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) {
      return res.status(401).json({ message: "Please log in to continue." });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.id);
    if (!user || !user.isActive) {
      return res.status(401).json({ message: "Account is not available." });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(401).json({ message: "Session expired. Please log in again." });
  }
}

function requireAccess(page) {
  return (req, res, next) => {
    if (!hasAccess(req.user, page)) {
      return res.status(403).json({ message: "You do not have access to this page." });
    }
    next();
  };
}

function signToken(user) {
  return jwt.sign(
    { id: user._id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || "7d" }
  );
}

function toUserResponse(user) {
  return {
    id: user._id,
    name: user.name,
    email: user.email,
    role: user.role,
    access: resolveAccess(user),
    isActive: user.isActive !== false,
    avatarUrl: user.avatarUrl || "",
  };
}

module.exports = { protect, requireAccess, signToken, toUserResponse };
