// Authenticated evidence download. Files live in a private folder and are never served statically.
const router = require('express').Router();
const path = require('path');
const { requireAuth } = require('../middleware/auth');
const M = require('../models');

router.get('/:id/download', requireAuth, async (req, res, next) => {
  try {
    const ev = await M.Evidence.findById(req.params.id);
    if (!ev) return res.status(404).json({ success: false, message: 'Not found.' });
    const c = await M.Complaint.findById(ev.complaintId);
    const u = req.user;
    let ok = u.roleName === 'Admin' || String(c.studentId) === String(u._id);
    if (!ok && u.roleName.startsWith('Committee'))
      ok = !!(await M.Assignment.findOne({ complaintId: c._id, assigneeId: u._id, active: true, conflictDeclared: { $ne: true } }));
    if (!ok) return res.status(403).json({ success: false, message: 'Access denied.' });
    await M.EvidenceAccessLog.create({ evidenceId: ev._id, userId: u._id, action: 'download' });
    res.download(path.resolve(process.env.UPLOAD_DIR || './private_uploads', ev.storedName), ev.originalName);
  } catch (e) { next(e); }
});

module.exports = router;
