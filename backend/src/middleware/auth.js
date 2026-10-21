const jwt = require('jsonwebtoken');
const { User } = require('../models');

async function requireAuth(req, res, next) {
  try {
    const token = (req.headers.authorization || '').replace(/^Bearer /, '');
    if (!token) return res.status(401).json({ success: false, message: 'Please sign in.' });
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(payload.sub);
    if (!user || user.status !== 'active') return res.status(401).json({ success: false, message: 'Account not available.' });
    req.user = user;
    next();
  } catch {
    res.status(401).json({ success: false, message: 'Session expired. Please sign in again.' });
  }
}

const requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.user.roleName) ? next() : res.status(403).json({ success: false, message: 'You do not have access to this.' });

module.exports = { requireAuth, requireRole };
