// Creates the first admin. Credentials come from env vars or a prompt; nothing is hardcoded.
// Run (PowerShell):  $env:ADMIN_EMAIL="you@gmail.com"; $env:ADMIN_PASSWORD="StrongPass#123"; npm run admin:create
// Or just run `npm run admin:create` and answer the prompts.
require('dotenv').config();
const readline = require('readline');
const bcrypt = require('bcryptjs');
const { connectDB, mongoose } = require('../config/database');
const { User, Role } = require('../models');

const ask = (q) => new Promise((res) => { const rl = readline.createInterface({ input: process.stdin, output: process.stdout }); rl.question(q, (a) => { rl.close(); res(a.trim()); }); });

(async () => {
  const email = (process.env.ADMIN_EMAIL || await ask('Admin email: ')).toLowerCase();
  const fullName = process.env.ADMIN_NAME || 'System Administrator';
  const password = process.env.ADMIN_PASSWORD || await ask('Admin password (min 10 chars): ');
  if (password.length < 10) throw new Error('Password must be at least 10 characters.');

  await connectDB();
  const role = await Role.findOne({ name: 'Admin' });
  if (!role) throw new Error('Admin role missing. Run npm run db:seed first.');
  if (await User.findOne({ email })) { console.log('A user with this email already exists. Nothing changed.'); }
  else {
    await User.create({ fullName, email, passwordHash: await bcrypt.hash(password, 12), roleId: role._id, roleName: 'Admin' });
    console.log('Admin created:', email);
  }
  await mongoose.disconnect();
})().catch((e) => { console.error(e.message); process.exit(1); });
