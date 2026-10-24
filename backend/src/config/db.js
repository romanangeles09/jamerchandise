const mongoose = require("mongoose");

async function connectDb() {
  const uri = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/jamerchandise";
  await mongoose.connect(uri);
  console.log(`MongoDB connected: ${mongoose.connection.name}`);
}

module.exports = connectDb;
