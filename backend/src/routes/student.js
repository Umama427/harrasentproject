const router = require('express').Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const mongoose = require('mongoose');
const { requireAuth, requireRole } = require('../middleware/auth');
const M = require('../models');
const wf = require('../services/workflow');

router.use(requireAuth, requireRole('Student'));

const uploadDir = path.resolve(process.env.UPLOAD_DIR || './private_uploads');
fs.mkdirSync(uploadDir, { recursive: true });
const ALLOWED = ['.jpg', '.jpeg', '.png', '.pdf', '.docx', '.txt'];
const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDir,
    filename: (req, file, cb) => cb(null, crypto.randomUUID() + path.extname(file.originalname).toLowerCase()),
  }),
  limits: { fileSize: Number(process.env.MAX_UPLOAD_MB || 10) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ok = ALLOWED.includes(path.extname(file.originalname).toLowerCase());
    cb(ok ? null : new Error('File type not allowed. Use jpg, png, pdf, docx or txt.'), ok);
  },
});

const own = (req) => M.Complaint.findOne({ _id: req.params.id, studentId: req.user._id });

router.get('/dashboard', async (req, res, next) => {
  try {
    const mine = { studentId: req.user._id };
    const count = (f) => M.Complaint.countDocuments({ ...mine, ...f });
    const [total, pending, investigating, resolved, notifications] = await Promise.all([
      count({ status: { $ne: 'Draft' } }),
      count({ status: { $in: ['Submitted', 'Under Initial Review', 'Awaiting Assignment', 'Assigned'] } }),
      count({ status: { $in: ['Under Investigation', 'Awaiting Student Information', 'Awaiting Committee Decision'] } }),
      count({ status: { $in: ['Resolved', 'Closed'] } }),
      M.Notification.find({ userId: req.user._id }).sort({ createdAt: -1 }).limit(5),
    ]);
    res.json({ success: true, data: { total, pending, investigating, resolved, notifications } });
  } catch (e) { next(e); }
});

// Create a complaint. Send submit:true to submit now, otherwise it is saved as a Draft.
router.post('/complaints', async (req, res, next) => {
  try {
    const b = req.body;
    if (!b.title || !b.description) return res.status(400).json({ success: false, message: 'Title and description are required.' });
    const submit = b.submit === true;
    if (submit && b.acknowledged !== true) return res.status(400).json({ success: false, message: 'Please accept the acknowledgement.' });
    const c = await M.Complaint.create({
      studentId: req.user._id, title: String(b.title), description: String(b.description),
      categoryId: b.categoryId, incidentDate: b.incidentDate, incidentLocation: b.incidentLocation,
      departmentId: b.departmentId || req.user.departmentId, semesterId: b.semesterId || req.user.semesterId,
      accused: { name: b.accusedName, relationship: b.accusedRelationship },
      safeContactMethod: b.safeContactMethod, confidential: b.confidential !== false,
      immediateSafetyConcern: b.immediateSafetyConcern === true, status: 'Draft',
    });
    if (Array.isArray(b.witnesses)) {
      await M.Witness.insertMany(b.witnesses.filter((w) => w && w.name).map((w) => ({ complaintId: c._id, name: w.name, contact: w.contact, statement: w.statement })));
    }
    if (submit) {
      c.referenceNo = await wf.nextReference();
      await wf.changeStatus(c, 'Submitted', req.user, 'Submitted by student');
      await M.ConsentRecord.create({ userId: req.user._id, complaintId: c._id, type: 'complaint_acknowledgement', accepted: true });
      await wf.notifyAdmins('New complaint', `${c.referenceNo} was submitted.`, c._id);
      await wf.notify(req.user._id, 'Complaint submitted', `Your reference number is ${c.referenceNo}.`, c._id);
    }
    res.status(201).json({ success: true, data: { id: c._id, referenceNo: c.referenceNo, status: c.status } });
  } catch (e) { next(e); }
});

// Submit an existing draft.
router.post('/complaints/:id/submit', async (req, res, next) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ success: false, message: 'Invalid complaint id.' });
    }
    const c = await own(req);
    if (!c) return res.status(404).json({ success: false, message: 'Complaint not found.' });
    c.referenceNo = c.referenceNo || await wf.nextReference();
    await wf.changeStatus(c, 'Submitted', req.user, 'Submitted by student');
    await wf.notifyAdmins('New complaint', `${c.referenceNo} was submitted.`, c._id);
    res.json({ success: true, data: { referenceNo: c.referenceNo, status: c.status } });
  } catch (e) { next(e); }
});

router.get('/complaints', async (req, res, next) => {
  try {
    const filter = { studentId: req.user._id };
    if (req.query.status) filter.status = String(req.query.status);
    const items = await M.Complaint.find(filter).populate('categoryId', 'name').sort({ createdAt: -1 });
    res.json({ success: true, data: items });
  } catch (e) { next(e); }
});

// Students see status timeline and evidence only. Internal notes and reviews are never returned.
router.get('/complaints/:id', async (req, res, next) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ success: false, message: 'Invalid complaint id.' });
    }
    const c = await own(req).then((x) => x && x.populate('categoryId', 'name'));
    if (!c) return res.status(404).json({ success: false, message: 'Complaint not found.' });
    const [timeline, evidence] = await Promise.all([
      M.StatusHistory.find({ complaintId: c._id }).sort({ createdAt: 1 }).select('fromStatus toStatus createdAt'),
      M.Evidence.find({ complaintId: c._id }).select('originalName mimeType size createdAt'),
    ]);
    res.json({ success: true, data: { complaint: c, timeline, evidence } });
  } catch (e) { next(e); }
});

router.post('/complaints/:id/evidence', (req, res, next) => {
  upload.single('file')(req, res, (err) => {
    if (err) {
      console.error('[EVIDENCE UPLOAD] Multer error:', err.message);
      return res.status(400).json({ success: false, message: err.message || 'File upload failed.' });
    }
    next();
  });
}, async (req, res, next) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      console.error('[EVIDENCE UPLOAD] Invalid complaint id:', req.params.id);
      return res.status(400).json({ success: false, message: 'Invalid complaint id.' });
    }
    if (!req.file) {
      console.error('[EVIDENCE UPLOAD] No file received in request.');
      return res.status(400).json({ success: false, message: 'No file received. Please choose a file and try again.' });
    }
    const c = await own(req);
    if (!c) {
      console.error('[EVIDENCE UPLOAD] Complaint not found for id:', req.params.id, 'student:', req.user._id);
      return res.status(404).json({ success: false, message: 'Complaint not found.' });
    }
    const sha256 = crypto.createHash('sha256').update(fs.readFileSync(req.file.path)).digest('hex');
    const ev = await M.Evidence.create({
      complaintId: c._id, uploadedBy: req.user._id, originalName: req.file.originalname,
      storedName: req.file.filename, mimeType: req.file.mimetype, size: req.file.size, sha256,
    });
    if (req.file.mimetype.startsWith('image/')) {
      await M.EvidenceAnalysis.create({
        evidenceId: ev._id, provider: 'none', result: 'Analysis unavailable',
        limitations: 'No AI-detection provider configured. Results from any provider are indicative only.',
      });
    }
    console.log('[EVIDENCE UPLOAD] Success:', ev._id, req.file.originalname);
    res.status(201).json({ success: true, data: { id: ev._id } });
  } catch (e) {
    console.error('[EVIDENCE UPLOAD] Unexpected error:', e);
    next(e);
  }
});

router.get('/notifications', async (req, res, next) => {
  try { res.json({ success: true, data: await M.Notification.find({ userId: req.user._id }).sort({ createdAt: -1 }).limit(50) }); } catch (e) { next(e); }
});
router.post('/notifications/:id/read', async (req, res, next) => {
  try { await M.Notification.updateOne({ _id: req.params.id, userId: req.user._id }, { isRead: true }); res.json({ success: true }); } catch (e) { next(e); }
});

module.exports = router;