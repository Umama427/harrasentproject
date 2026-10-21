// Safe & idempotent: creates missing collections/indexes and removes one obsolete index.
// Never drops collections or documents.
// Run: npm run db:init
require('dotenv').config();
const { connectDB, mongoose } = require('../config/database');
const models = require('../models');

(async () => {
  await connectDB();
  const existing = new Set((await mongoose.connection.db.listCollections().toArray()).map((c) => c.name));
  if (existing.has('complaints')) {
    const complaints = mongoose.connection.db.collection('complaints');
    const indexes = await complaints.indexes();
    const obsoleteReferenceIndex = indexes.find((index) =>
      index.unique &&
      Object.keys(index.key).length === 1 &&
      index.key.referenceNumber === 1
    );
    if (obsoleteReferenceIndex) {
      await complaints.dropIndex(obsoleteReferenceIndex.name);
      console.log('dropped obsolete index:', obsoleteReferenceIndex.name);
    }
  }
  for (const m of Object.values(models)) {
    if (!m || !m.collection || !m.modelName) continue;
    const name = m.collection.name;
    if (!existing.has(name)) { await m.createCollection(); console.log('created collection:', name); }
    try { await m.createIndexes(); /* adds only; never drops existing indexes */ } catch (e) { console.warn(`index warning on ${name}: ${e.message}`); }
  }
  console.log('Database initialisation complete (no collections or documents were deleted).');
  await mongoose.disconnect();
})().catch((e) => { console.error(e.message); process.exit(1); });
