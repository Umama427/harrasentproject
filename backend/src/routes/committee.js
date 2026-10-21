const router = require('express').Router();
const { requireAuth, requireRole } = require('../middleware/auth');
const M = require('../models');
const wf = require('../services/workflow');

router.use(requireAuth, requireRole('Committee Member', 'Committee HOD'));

async function assigned(req, res, next) {
  const a = await M.Assignment.findOne({ complaintId: req.params.id, assigneeId: req.user._id, active: true, conflictDeclared: { $ne: true } });
  if (!a) return res.status(403).json({ success: false, message: 'This case is not assigned to you.' });
  req.complaint = await M.Complaint.findById(req.params.id);
  next();
}

router.get('/dashboard', async (req, res, next) => {
  try {
    const mine = await M.Assignment.find({ assigneeId: req.user._id, active: true, conflictDeclared: { $ne: true } }).distinct('complaintId');
    const count = (statuses) => M.Complaint.countDocuments({ _id: { $in: mine }, status: { $in: statuses } });
    const [assignedNew, investigating, awaitingInfo, awaitingDecision, resolved] = await Promise.all([
      count(['Assigned']), count(['Under Investigation']), count(['Awaiting Student Information']),
      count(['Awaiting Committee Decision']), count(['Resolved', 'Closed']),
    ]);
    res.json({ success: true, data: { totalAssigned: mine.length, assignedNew, investigating, awaitingInfo, awaitingDecision, resolved } });
  } catch (e) { next(e); }
});

router.get('/cases', async (req, res, next) => {
  try {
    const ids = await M.Assignment.find({ assigneeId: req.user._id, active: true, conflictDeclared: { $ne: true } }).distinct('complaintId');
    const cases = await M.Complaint.find({ _id: { $in: ids } }).populate('categoryId', 'name').sort({ updatedAt: -1 });
    res.json({ success: true, data: cases });
  } catch (e) { next(e); }
});

router.get('/cases/:id', assigned, async (req, res, next) => {
  try {
    const id = req.complaint._id;
    const [timeline, notes, witnesses, evidence, reviews] = await Promise.all([
      M.StatusHistory.find({ complaintId: id }).sort({ createdAt: 1 }),
      M.InvestigationNote.find({ complaintId: id }).sort({ createdAt: -1 }),
      M.Witness.find({ complaintId: id }),
      M.Evidence.find({ complaintId: id }),
      M.CaseReview.find({ complaintId: id }).sort({ createdAt: -1 }),
    ]);
    const analyses = await M.EvidenceAnalysis.find({ evidenceId: { $in: evidence.map((e) => e._id) } });
    res.json({ success: true, data: { complaint: req.complaint, timeline, notes, witnesses, evidence, analyses, reviews } });
  } catch (e) { next(e); }
});

router.post('/cases/:id/notes', assigned, async (req, res, next) => {
  try {
    if (!req.body.note) return res.status(400).json({ success: false, message: 'Note cannot be empty.' });
    const n = await M.InvestigationNote.create({ complaintId: req.complaint._id, authorId: req.user._id, note: String(req.body.note) });
    res.status(201).json({ success: true, data: n });
  } catch (e) { next(e); }
});

router.post('/cases/:id/status', assigned, async (req, res, next) => {
  try {
    await wf.changeStatus(req.complaint, String(req.body.status), req.user, req.body.reason);
    if (req.complaint.status === 'Awaiting Student Information')
      await wf.notify(req.complaint.studentId, 'More information needed', 'The committee needs more information about your complaint.', req.complaint._id);
    res.json({ success: true, data: { status: req.complaint.status } });
  } catch (e) { next(e); }
});

router.post('/cases/:id/review', assigned, async (req, res, next) => {
  try {
    const r = await M.CaseReview.create({ complaintId: req.complaint._id, reviewerId: req.user._id, findings: req.body.findings, recommendation: req.body.recommendation });
    res.status(201).json({ success: true, data: r });
  } catch (e) { next(e); }
});

// Committee member can ask the student to attach evidence.
router.post('/cases/:id/request-evidence', assigned, async (req, res, next) => {
  try {
    await wf.notify(
      req.complaint.studentId,
      'Evidence requested',
      `The committee has requested that you attach supporting evidence (photos, screenshots, or documents) for complaint ${req.complaint.referenceNo}. Open it from "My Complaints" and use "Attach file".`,
      req.complaint._id
    );
    res.json({ success: true, message: 'Request sent to the student.' });
  } catch (e) { next(e); }
});

// Declaring a conflict removes your access until an admin reassigns the case.
router.post('/cases/:id/conflict', assigned, async (req, res, next) => {
  try {
    await M.Assignment.updateOne({ complaintId: req.complaint._id, assigneeId: req.user._id, active: true }, { conflictDeclared: true, conflictReason: req.body.reason });
    req.complaint.assignedTo = undefined; await req.complaint.save();
    await wf.notifyAdmins('Conflict of interest declared', `A committee member declared a conflict on ${req.complaint.referenceNo}. Please reassign.`, req.complaint._id);
    await M.AuditLog.create({ actorId: req.user._id, action: 'conflict_declared', targetType: 'Complaint', targetId: req.complaint._id });
    res.json({ success: true, message: 'Conflict recorded. You no longer have access to this case.' });
  } catch (e) { next(e); }
});

module.exports = router;