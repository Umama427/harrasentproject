const { Complaint, StatusHistory, Notification, AuditLog, User, Counter } = require('../models');

// Allowed status changes per role. The frontend can never set a status directly.
const TRANSITIONS = {
  Student: { Draft: ['Submitted'] },
  Admin: {
    Submitted: ['Under Initial Review', 'Rejected'],
    'Under Initial Review': ['Awaiting Assignment', 'Rejected'],
    'Awaiting Assignment': ['Assigned'],
    Assigned: ['Awaiting Assignment'],
    Resolved: ['Closed', 'Reopened'],
    Closed: ['Reopened'],
    Reopened: ['Awaiting Assignment'],
  },
  Committee: {
    Assigned: ['Under Investigation'],
    'Under Investigation': ['Awaiting Student Information', 'Awaiting Committee Decision'],
    'Awaiting Student Information': ['Under Investigation'],
    'Awaiting Committee Decision': ['Resolved', 'Under Investigation'],
  },
};

function canMove(roleName, from, to) {
  const key = roleName.startsWith('Committee') ? 'Committee' : roleName;
  return !!(TRANSITIONS[key] && TRANSITIONS[key][from] && TRANSITIONS[key][from].includes(to));
}

async function changeStatus(complaint, to, actor, reason) {
  if (!canMove(actor.roleName, complaint.status, to)) {
    const err = new Error(`Status change ${complaint.status} -> ${to} is not allowed for your role.`);
    err.status = 400; throw err;
  }
  const from = complaint.status;
  complaint.status = to;
  await complaint.save();
  await StatusHistory.create({ complaintId: complaint._id, fromStatus: from, toStatus: to, actorId: actor._id, reason });
  await AuditLog.create({ actorId: actor._id, action: 'status_change', targetType: 'Complaint', targetId: complaint._id, details: { from, to } });
}

async function notify(userId, title, message, complaintId) {
  await Notification.create({ userId, title, message, complaintId });
}

async function notifyAdmins(title, message, complaintId) {
  const admins = await User.find({ roleName: 'Admin', status: 'active' }).select('_id');
  await Promise.all(admins.map((a) => notify(a._id, title, message, complaintId)));
}

async function nextReference() {
  const c = await Counter.findOneAndUpdate({ _id: 'complaint' }, { $inc: { seq: 1 } }, { new: true, upsert: true });
  return `HC-${new Date().getFullYear()}-${String(c.seq).padStart(5, '0')}`;
}

module.exports = { canMove, changeStatus, notify, notifyAdmins, nextReference };
