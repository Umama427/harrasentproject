require('dotenv').config();
if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  console.error('Set JWT_SECRET (32+ characters) in .env first.');
  process.exit(1);
}
const { connectDB } = require('./config/database');
const app = require('./app');

connectDB()
  .then(() => app.listen(process.env.PORT || 4000, () => console.log(`API on http://localhost:${process.env.PORT || 4000}/api/health`)))
  .catch((e) => { console.error('Could not start:', e.message); process.exit(1); });
