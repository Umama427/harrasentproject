require('dotenv').config();
const mongoose = require('mongoose');

async function connectDB() {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017';
  const dbName = process.env.DB_NAME || 'university_harassment_db';
  await mongoose.connect(uri, { dbName });
  console.log(`MongoDB connected -> ${dbName}`);
}

module.exports = { connectDB, mongoose };
