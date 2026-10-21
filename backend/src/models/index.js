const mongoose = require('mongoose');
const { Schema } = mongoose;

function define(name, collection, fields = {}) {
  const schema = new Schema(fields, {
    collection,
    timestamps: true,
    strict: false,
  });
  return mongoose.models[name] || mongoose.model(name, schema, collection);
}

const ref = (model) => ({ type: Schema.Types.ObjectId, ref: model });

const Role = define('Role', 'roles', {
  name: String,
  description: String,
  permissions: [String],
  isSystem: Boolean,
});

const User = define('User', 'users', {
  fullName: String,
  email: String,
  registrationNumber: String,
  passwordHash: { type: String, select: false },
  roleId: ref('Role'),
  roleName: String,
  departmentId: ref('Department'),
  semesterId: ref('Semester'),
  status: { type: String, default: 'active' },
  emailVerified: Boolean,
});

const Department = define('Department', 'departments', {
  name: String, code: String, isActive: Boolean,
});
const Semester = define('Semester', 'semesters', {
  name: String, code: String, number: Number, isActive: Boolean,
});
const Category = define('Category', 'complaint_categories', {
  name: String, description: String, isActive: Boolean, severityDefault: String,
});
const Gender = define('Gender', 'genders', {
  label: String, name: String, isActive: Boolean,
});
const Policy = define('Policy', 'policies', {
  title: String, content: String, version: String, effectiveDate: Date, isActive: Boolean,
});
const SupportService = define('SupportService', 'support_services', {
  name: String, description: String, contactEmail: String, contactPhone: String,
  location: String, hours: String, sortOrder: Number, isActive: Boolean,
});
const Process = define('Process', 'processes', {
  name: String, steps: [Schema.Types.Mixed], isActive: Boolean,
});

const Complaint = define('Complaint', 'complaints', {
  studentId: ref('User'),
  title: String,
  categoryId: ref('Category'),
  description: String,
  incidentDate: Date,
  incidentLocation: String,
  departmentId: ref('Department'),
  semesterId: ref('Semester'),
  accused: Schema.Types.Mixed,
  safeContactMethod: String,
  confidential: Boolean,
  immediateSafetyConcern: Boolean,
  status: String,
  referenceNo: String,
  assignedTo: ref('User'),
});

const StatusHistory = define('StatusHistory', 'complaint_status_history', {
  complaintId: ref('Complaint'), fromStatus: String, toStatus: String,
  actorId: ref('User'), reason: String,
});
const Notification = define('Notification', 'notifications', {
  userId: ref('User'), title: String, message: String, complaintId: ref('Complaint'), isRead: Boolean,
});
const AuditLog = define('AuditLog', 'audit_logs', {
  actorId: ref('User'), action: String, targetType: String,
  targetId: Schema.Types.ObjectId, details: Schema.Types.Mixed,
});
const Counter = define('Counter', 'counters', {
  _id: String, seq: Number,
});

const Assignment = define('Assignment', 'committee_assignments', {
  complaintId: ref('Complaint'), assigneeId: ref('User'), assignedBy: ref('User'),
  active: Boolean, conflictDeclared: Boolean, conflictReason: String,
});
const CommitteeMember = define('CommitteeMember', 'committee_members', {
  userId: ref('User'), departmentId: ref('Department'), designation: String,
  isEligible: Boolean, isActive: Boolean, joinedAt: Date,
});
const InvestigationNote = define('InvestigationNote', 'investigation_notes', {
  complaintId: ref('Complaint'), authorId: ref('User'), note: String,
});
const Witness = define('Witness', 'witnesses', {
  complaintId: ref('Complaint'), name: String, contact: String, statement: String,
});
const CaseReview = define('CaseReview', 'case_reviews', {
  complaintId: ref('Complaint'), reviewerId: ref('User'), findings: String, recommendation: String,
});

const Evidence = define('Evidence', 'evidence', {
  complaintId: ref('Complaint'), uploadedBy: ref('User'), originalName: String,
  storedName: String, mimeType: String, size: Number, sha256: String,
});
const EvidenceAnalysis = define('EvidenceAnalysis', 'evidence_analysis', {
  evidenceId: ref('Evidence'), provider: String, result: String, limitations: String,
});
const EvidenceAccessLog = define('EvidenceAccessLog', 'evidence_access_logs', {
  evidenceId: ref('Evidence'), userId: ref('User'), action: String,
});

const Profile = define('Profile', 'profiles', {
  userId: ref('User'), fullName: String,
});
const Registration = define('Registration', 'registrations', {
  userId: ref('User'), email: String, registrationNumber: String, status: String,
});
const ConsentRecord = define('ConsentRecord', 'consent_records', {
  userId: ref('User'), complaintId: ref('Complaint'), type: String, accepted: Boolean,
});
const OtpVerification = define('OtpVerification', 'otp_verifications', {
  userId: ref('User'), otpHash: String, expiresAt: Date, attempts: Number, used: Boolean,
});

const SupportRequest = define('SupportRequest', 'support_requests', {});
const NotificationPreference = define('NotificationPreference', 'notification_preferences', {});
const PasswordResetToken = define('PasswordResetToken', 'password_reset_tokens', {});
const RefreshToken = define('RefreshToken', 'refresh_tokens', {});
const SystemSetting = define('SystemSetting', 'system_settings', {
  key: String, value: Schema.Types.Mixed, description: String, isPublic: Boolean,
});

module.exports = {
  Role, User, Department, Semester, Category, Gender, Policy, SupportService, Process,
  Complaint, StatusHistory, Notification, AuditLog, Counter, Assignment, CommitteeMember,
  InvestigationNote, Witness, CaseReview, Evidence, EvidenceAnalysis, EvidenceAccessLog,
  Profile, Registration, ConsentRecord, OtpVerification, SupportRequest,
  NotificationPreference, PasswordResetToken, RefreshToken, SystemSetting,
};