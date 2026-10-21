const router = require('express').Router();
const bcrypt = require('bcryptjs');
const { requireAuth, requireRole } = require('../middleware/auth');
const M = require('../models');
const wf = require('../services/workflow');

router.use(requireAuth, requireRole('Admin'));
const audit = (req, action, targetType, targetId, details) => M.AuditLog.create({ actorId: req.user._id, action, targetType, targetId, details });

router.get('/dashboard', async (req, res, next) => {
  try {
    const c = (f) => M.Complaint.countDocuments(f);
    const [users, students, committee, total, pending, investigating, resolved, byDepartment, bySemester, byCategory, recent] = await Promise.all([
      M.User.countDocuments(), M.User.countDocuments({ roleName: 'Student' }),
      M.User.countDocuments({ roleName: { $in: ['Committee Member', 'Committee HOD'] } }),
      c({ status: { $ne: 'Draft' } }),
      c({ status: { $in: ['Submitted', 'Under Initial Review', 'Awaiting Assignment'] } }),
      c({ status: { $in: ['Assigned', 'Under Investigation', 'Awaiting Student Information', 'Awaiting Committee Decision'] } }),
      c({ status: { $in: ['Resolved', 'Closed'] } }),
      M.Complaint.aggregate([{ $match: { status: { $ne: 'Draft' } } }, { $group: { _id: '$departmentId', count: { $sum: 1 } } }]),
      M.Complaint.aggregate([{ $match: { status: { $ne: 'Draft' } } }, { $group: { _id: '$semesterId', count: { $sum: 1 } } }]),
      M.Complaint.aggregate([{ $match: { status: { $ne: 'Draft' } } }, { $group: { _id: '$categoryId', count: { $sum: 1 } } }]),
      M.AuditLog.find().sort({ createdAt: -1 }).limit(10),
    ]);
    res.json({ success: true, data: { users, students, committee, total, pending, investigating, resolved, byDepartment, bySemester, byCategory, recent } });
  } catch (e) { next(e); }
});

router.get('/complaints', async (req, res, next) => {
  try {
    const filter = { status: { $ne: 'Draft' } };
    if (req.query.status) filter.status = String(req.query.status);
    const page = Math.max(1, Number(req.query.page) || 1), limit = 20;
    const [items, total] = await Promise.all([
      M.Complaint.find(filter).populate('studentId', 'fullName registrationNumber').populate('categoryId', 'name').populate('assignedTo', 'fullName')
        .sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
      M.Complaint.countDocuments(filter),
    ]);
    res.json({ success: true, data: items, meta: { page, limit, total } });
  } catch (e) { next(e); }
});

router.get('/complaints/:id', async (req, res, next) => {
  try {
    const c = await M.Complaint.findById(req.params.id).populate('studentId', 'fullName email registrationNumber').populate('categoryId', 'name');
    if (!c) return res.status(404).json({ success: false, message: 'Not found.' });
    const [timeline, evidence, assignments] = await Promise.all([
      M.StatusHistory.find({ complaintId: c._id }).sort({ createdAt: 1 }),
      M.Evidence.find({ complaintId: c._id }), M.Assignment.find({ complaintId: c._id }).populate('assigneeId', 'fullName'),
    ]);
    res.json({ success: true, data: { complaint: c, timeline, evidence, assignments } });
  } catch (e) { next(e); }
});

router.post('/complaints/:id/status', async (req, res, next) => {
  try {
    const c = await M.Complaint.findById(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: 'Not found.' });
    await wf.changeStatus(c, String(req.body.status), req.user, req.body.reason);
    await wf.notify(c.studentId, 'Complaint update', `Your complaint ${c.referenceNo} is now: ${c.status}.`, c._id);
    res.json({ success: true, data: { status: c.status } });
  } catch (e) { next(e); }
});

// Admin can nudge a student to attach evidence, whether or not they have any already.
router.post('/complaints/:id/request-evidence', async (req, res, next) => {
  try {
    const c = await M.Complaint.findById(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: 'Not found.' });
    await wf.notify(
      c.studentId,
      'Evidence requested',
      `Please attach supporting evidence (photos, screenshots, or documents) for complaint ${c.referenceNo}. Open the complaint from "My Complaints" and use "Attach file".`,
      c._id
    );
    await audit(req, 'request_evidence', 'Complaint', c._id);
    res.json({ success: true, message: 'Request sent to the student.' });
  } catch (e) { next(e); }
});

// Assign to an active committee member / HOD who has not declared a conflict on this case.
router.post('/complaints/:id/assign', async (req, res, next) => {
  try {
    const c = await M.Complaint.findById(req.params.id);
    if (!c) return res.status(404).json({ success: false, message: 'Not found.' });
    const assignee = await M.User.findById(String(req.body.assigneeId));
    const membership = assignee && await M.CommitteeMember.findOne({ userId: assignee._id, isActive: true });
    if (!assignee || !['Committee Member', 'Committee HOD'].includes(assignee.roleName) || !membership)
      return res.status(400).json({ success: false, message: 'Selected person is not an active committee member.' });
    if (await M.Assignment.findOne({ complaintId: c._id, assigneeId: assignee._id, conflictDeclared: true }))
      return res.status(400).json({ success: false, message: 'This member declared a conflict on this case.' });

    if (!['Awaiting Assignment', 'Assigned'].includes(c.status)) {
      if (c.status === 'Submitted') await wf.changeStatus(c, 'Under Initial Review', req.user, 'Reviewed by admin');
      if (c.status === 'Under Initial Review') await wf.changeStatus(c, 'Awaiting Assignment', req.user, 'Ready for assignment');
    }
    await M.Assignment.updateMany({ complaintId: c._id, active: true }, { active: false });
    await M.Assignment.create({ complaintId: c._id, assigneeId: assignee._id, assignedBy: req.user._id });
    c.assignedTo = assignee._id;
    if (c.status === 'Awaiting Assignment') await wf.changeStatus(c, 'Assigned', req.user, `Assigned to ${assignee.fullName}`);
    else await c.save();
    await wf.notify(assignee._id, 'New case assigned', `Case ${c.referenceNo} has been assigned to you.`, c._id);
    await audit(req, 'assign_complaint', 'Complaint', c._id, { assigneeId: assignee._id });
    res.json({ success: true, message: 'Complaint assigned.' });
  } catch (e) { next(e); }
});

router.get('/users', async (req, res, next) => {
  try {
    const filter = req.query.role ? { roleName: String(req.query.role) } : {};
    res.json({ success: true, data: await M.User.find(filter).select('-passwordHash').sort({ createdAt: -1 }).limit(200) });
  } catch (e) { next(e); }
});

router.post('/users/:id/status', async (req, res, next) => {
  try {
    if (!['active', 'suspended'].includes(req.body.status)) return res.status(400).json({ success: false, message: 'Invalid status.' });
    await M.User.updateOne({ _id: req.params.id }, { status: req.body.status });
    await audit(req, 'user_status', 'User', req.params.id, { status: req.body.status });
    res.json({ success: true });
  } catch (e) { next(e); }
});

// Create a committee member / HOD account (admin only; students cannot self-register into this role).
router.post('/committee-members', async (req, res, next) => {
  try {
    const { fullName, email, password, departmentId, designation } = req.body;
    if (!fullName || !email || !password || String(password).length < 8)
      return res.status(400).json({ success: false, message: 'Name, email and a password of 8+ characters are required.' });
    const roleName = designation === 'HOD' ? 'Committee HOD' : 'Committee Member';
    const role = await M.Role.findOne({ name: roleName });
    if (await M.User.findOne({ email: String(email).toLowerCase() })) return res.status(409).json({ success: false, message: 'Email already in use.' });
    const user = await M.User.create({ fullName, email: String(email).toLowerCase(), passwordHash: await bcrypt.hash(String(password), 12), roleId: role._id, roleName, departmentId });
    await M.CommitteeMember.create({ userId: user._id, departmentId, designation: designation === 'HOD' ? 'HOD' : 'Member' });
    await audit(req, 'create_committee_member', 'User', user._id);
    res.status(201).json({ success: true, data: { id: user._id } });
  } catch (e) { next(e); }
});

router.get('/committee-members', async (req, res, next) => {
  try { res.json({ success: true, data: await M.CommitteeMember.find().populate('userId', 'fullName email').populate('departmentId', 'name') }); } catch (e) { next(e); }
});

// Simple create endpoints for reference data and content.
const creators = { departments: M.Department, semesters: M.Semester, categories: M.Category, policies: M.Policy, 'support-services': M.SupportService };
for (const [path, Model] of Object.entries(creators)) {
  router.post(`/${path}`, async (req, res, next) => {
    try {
      const doc = await Model.create(req.body);
      await audit(req, `create_${path}`, Model.modelName, doc._id);
      res.status(201).json({ success: true, data: doc });
    } catch (e) { next(e); }
  });
}

router.get('/audit-logs', async (req, res, next) => {
  try { res.json({ success: true, data: await M.AuditLog.find().populate('actorId', 'fullName').sort({ createdAt: -1 }).limit(100) }); } catch (e) { next(e); }
});

module.exports = router;