// Read-only: prints how many documents each collection has and one sample document.
// Run: npm run db:inspect
require('dotenv').config();
const { connectDB, mongoose } = require('../config/database');

(async () => {
  await connectDB();
  const cols = await mongoose.connection.db.listCollections().toArray();
  for (const { name } of cols.sort((a, b) => a.name.localeCompare(b.name))) {
    const c = mongoose.connection.db.collection(name);
    const n = await c.countDocuments();
    console.log(`\n${name}: ${n} document(s)`);
    if (n) console.log(JSON.stringify(await c.findOne({}, { projection: { passwordHash: 0, otpHash: 0 } }), null, 2));
  }
  await mongoose.disconnect();
})().catch((e) => { console.error(e.message); process.exit(1); });
