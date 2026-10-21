const router = require('express').Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { User, Role, Profile, Registration, ConsentRecord, OtpVerification } = require('../models');
const { sendOtpEmail } = require('../services/mailer');
const { requireAuth } = require('../middleware/auth');

const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 30, standardHeaders: true, legacyHeaders: false });
const str = (v) => (typeof v === 'string' ? v.trim() : ''); // blocks NoSQL operator objects
const hash = (s) => crypto.createHash('sha256').update(s).digest('hex');

router.post('/register', limiter, async (req, res, next) => {
  try {
    const fullName = str(req.body.fullName), email = str(req.body.email).toLowerCase();
    const registrationNumber = str(req.body.registrationNumber), password = str(req.body.password);
    const { departmentId, semesterId, consent } = req.body;
    if (!fullName || !email || !registrationNumber || !departmentId || !semesterId)
      return res.status(400).json({ success: false, message: 'Please fill in all fields.' });
    if (!/^\S+@\S+\.\S+$/.test(email)) return res.status(400).json({ success: false, message: 'Enter a valid email.' });
    if (password.length < 8) return res.status(400).json({ success: false, message: 'Password must be at least 8 characters.' });
    if (consent !== true) return res.status(400).json({ success: false, message: 'Consent is required.' });

    if (await User.findOne({ $or: [{ email }, { registrationNumber }] }))
      return res.status(409).json({ success: false, message: 'You are already registered. Please sign in.' });

    const role = await Role.findOne({ name: 'Student' });
    const user = await User.create({
      fullName, email, registrationNumber, departmentId: str(departmentId), semesterId: str(semesterId),
      passwordHash: await bcrypt.hash(password, 12), roleId: role._id, roleName: 'Student',
    });
    await Profile.create({ userId: user._id });
    await Registration.create({ userId: user._id, email, registrationNumber });
    await ConsentRecord.create({ userId: user._id, type: 'registration', accepted: true });
    res.status(201).json({ success: true, message: 'Registered successfully. Please sign in.' });
  } catch (e) {
    if (e.code === 11000) return res.status(409).json({ success: false, message: 'You are already registered. Please sign in.' });
    next(e);
  }
});

// Step 1: check password, email a 6-digit code.
router.post('/login', limiter, async (req, res, next) => {
  try {
    const email = str(req.body.email).toLowerCase(), password = str(req.body.password);
    const user = await User.findOne({ email }).select('+passwordHash');
    if (!user || !(await bcrypt.compare(password, user.passwordHash)) || user.status !== 'active')
      return res.status(401).json({ success: false, message: 'Incorrect email or password.' });
    const otp = String(crypto.randomInt(100000, 1000000));
    const rec = await OtpVerification.create({ userId: user._id, otpHash: hash(otp), expiresAt: new Date(Date.now() + 5 * 60 * 1000) });
    await sendOtpEmail(user.email, otp);
    res.json({ success: true, message: 'A verification code was sent to your email.', data: { challengeId: rec._id } });
  } catch (e) { next(e); }
});

// Step 2: verify code -> JWT.
router.post('/verify-otp', limiter, async (req, res, next) => {
  try {
    const rec = await OtpVerification.findById(str(req.body.challengeId));
    const bad = () => res.status(401).json({ success: false, message: 'Invalid or expired code.' });
    if (!rec || rec.used || rec.expiresAt < new Date() || rec.attempts >= 5) return bad();
    if (rec.otpHash !== hash(str(req.body.otp))) { rec.attempts += 1; await rec.save(); return bad(); }
    rec.used = true; await rec.save();
    const user = await User.findById(rec.userId);
    const token = jwt.sign({ sub: user._id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '8h' });
    res.json({ success: true, data: { token, user: { id: user._id, fullName: user.fullName, email: user.email, role: user.roleName } } });
  } catch (e) { next(e); }
});

router.get('/me', requireAuth, (req, res) => {
  const u = req.user;
  res.json({ success: true, data: { id: u._id, fullName: u.fullName, email: u.email, role: u.roleName } });
});

module.exports = router;
