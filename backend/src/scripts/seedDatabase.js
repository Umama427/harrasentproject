require('dotenv').config();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { connectDB, mongoose } = require('../config/database');
const M = require('../models');
const wf = require('../services/workflow');

const daysAgo = (n) => new Date(Date.now() - n * 24 * 60 * 60 * 1000);

async function wipe() {
  const names = [
    'roles', 'departments', 'semesters', 'complaint_categories', 'genders',
    'policies', 'support_services', 'processes', 'system_settings',
    'users', 'profiles', 'registrations', 'consent_records',
    'committee_members', 'committee_assignments',
    'complaints', 'complaint_status_history', 'witnesses',
    'investigation_notes', 'case_reviews',
    'evidence', 'evidence_analysis', 'evidence_access_logs',
    'notifications', 'audit_logs', 'counters',
    'otp_verifications', 'refresh_tokens', 'password_reset_tokens',
  ];
  const db = mongoose.connection.db;
  for (const name of names) {
    await db.collection(name).deleteMany({}).catch(() => {});
  }
  console.log('Cleared previous seed data from', names.length, 'collections.');
}

async function seedReferenceData() {
  const roleDocs = {
    Student: ['complaint.create', 'complaint.view.own', 'evidence.upload', 'evidence.view.own'],
    'Committee Member': ['complaint.view.assigned', 'note.create', 'status.update'],
    'Committee HOD': ['complaint.view.assigned', 'note.create', 'status.update'],
    Admin: ['*'],
  };
  const roles = {};
  for (const [name, permissions] of Object.entries(roleDocs)) {
    roles[name] = await M.Role.create({ name, permissions, isSystem: true, description: name + ' role' });
  }

  const deptDefs = [
    ['Computer Science', 'CS'],
    ['Software Engineering', 'SE'],
    ['Business Administration', 'BBA'],
    ['Electrical Engineering', 'EE'],
    ['English', 'ENG'],
    ['Mathematics', 'MATH'],
  ];
  const departments = {};
  for (const [name, code] of deptDefs) {
    departments[code] = await M.Department.create({ name, code, isActive: true });
  }

  const semDefs = [
    ['Fall 2025', 'F2025', 1, false],
    ['Spring 2026', 'S2026', 2, false],
    ['Summer 2026', 'SU2026', 3, false],
    ['Fall 2026', 'F2026', 4, true],
  ];
  const semesters = {};
  for (const [name, code, number, isActive] of semDefs) {
    semesters[code] = await M.Semester.create({ name, code, number, isActive });
  }

  const catDefs = [
    ['Verbal Harassment', 'Unwanted verbal comments, insults, or threats.', 'medium'],
    ['Sexual Harassment', 'Unwelcome sexual behaviour or advances.', 'high'],
    ['Cyber Harassment', 'Harassment through online platforms or messages.', 'medium'],
    ['Discrimination', 'Unfair treatment based on identity.', 'high'],
    ['Bullying', 'Repeated intimidation or humiliation.', 'medium'],
    ['Physical Harassment', 'Unwanted physical contact or intimidation.', 'high'],
    ['Stalking', 'Repeated unwanted attention or following.', 'high'],
    ['Other', 'A complaint that does not fit another listed category.', 'low'],
  ];
  const categories = {};
  for (const [name, description, severityDefault] of catDefs) {
    categories[name] = await M.Category.create({ name, description, isActive: true, severityDefault });
  }

  const genderDefs = ['Male', 'Female', 'Other', 'Prefer not to say'];
  for (const label of genderDefs) {
    await M.Gender.create({ label, name: label, isActive: true });
  }

  const policyDefs = [
    ['Anti-Harassment Policy', 'The university is committed to providing a safe, respectful environment free from harassment of any kind. This policy outlines prohibited behaviours, reporting channels, and the investigation process.', '1.0'],
    ['Code of Conduct', 'All students, faculty, and staff are expected to behave with integrity, respect, and professionalism in all university interactions, both on and off campus.', '1.2'],
    ['Confidentiality Policy', 'All harassment complaints are handled with strict confidentiality. Information is shared only with individuals directly involved in the investigation on a need-to-know basis.', '1.0'],
  ];
  for (const [title, content, version] of policyDefs) {
    await M.Policy.create({ title, content, version, effectiveDate: daysAgo(180), isActive: true });
  }

  const serviceDefs = [
    ['Student Counseling Center', 'Confidential counseling and mental-health support.', 'counseling@university.edu', '+1-555-0100', 'Student Center, Room 204', 'Mon-Fri 9:00-17:00', 1],
    ['Legal Aid Office', 'Free legal advice and guidance for students involved in a complaint.', 'legalaid@university.edu', '+1-555-0122', 'Admin Block, Room 110', 'Mon-Fri 10:00-16:00', 2],
    ['Student Ombudsperson', 'Independent, impartial resource for resolving conflicts and concerns.', 'ombudsperson@university.edu', '+1-555-0133', 'Library Building, Room 305', 'Tue-Thu 9:00-13:00', 3],
  ];
  for (const [name, description, contactEmail, contactPhone, location, hours, sortOrder] of serviceDefs) {
    await M.SupportService.create({ name, description, contactEmail, contactPhone, location, hours, sortOrder, isActive: true });
  }

  await M.Process.create({
    name: 'Standard Harassment Complaint Flow',
    isActive: true,
    steps: [
      { from: 'Draft', to: 'Submitted', allowedRoles: ['Student'], requiresReason: false },
      { from: 'Submitted', to: 'Under Initial Review', allowedRoles: ['Admin'], requiresReason: false },
      { from: 'Submitted', to: 'Rejected', allowedRoles: ['Admin'], requiresReason: true },
      { from: 'Under Initial Review', to: 'Awaiting Assignment', allowedRoles: ['Admin'], requiresReason: false },
      { from: 'Under Initial Review', to: 'Rejected', allowedRoles: ['Admin'], requiresReason: true },
      { from: 'Awaiting Assignment', to: 'Assigned', allowedRoles: ['Admin'], requiresReason: false },
      { from: 'Assigned', to: 'Awaiting Assignment', allowedRoles: ['Admin'], requiresReason: false },
      { from: 'Assigned', to: 'Under Investigation', allowedRoles: ['Committee Member', 'Committee HOD'], requiresReason: false },
      { from: 'Under Investigation', to: 'Awaiting Student Information', allowedRoles: ['Committee Member', 'Committee HOD'], requiresReason: false },
      { from: 'Under Investigation', to: 'Awaiting Committee Decision', allowedRoles: ['Committee Member', 'Committee HOD'], requiresReason: false },
      { from: 'Awaiting Student Information', to: 'Under Investigation', allowedRoles: ['Committee Member', 'Committee HOD'], requiresReason: false },
      { from: 'Awaiting Committee Decision', to: 'Resolved', allowedRoles: ['Committee Member', 'Committee HOD'], requiresReason: false },
      { from: 'Awaiting Committee Decision', to: 'Under Investigation', allowedRoles: ['Committee Member', 'Committee HOD'], requiresReason: false },
      { from: 'Resolved', to: 'Closed', allowedRoles: ['Admin'], requiresReason: false },
      { from: 'Resolved', to: 'Reopened', allowedRoles: ['Admin'], requiresReason: true },
      { from: 'Closed', to: 'Reopened', allowedRoles: ['Admin'], requiresReason: true },
      { from: 'Reopened', to: 'Awaiting Assignment', allowedRoles: ['Admin'], requiresReason: false },
    ],
  });

  await M.SystemSetting.create({ key: 'university_name', value: 'Example University', description: 'Displayed in the UI header', isPublic: true });
  await M.SystemSetting.create({ key: 'support_email', value: 'support@university.edu', description: 'Shown on the help page', isPublic: true });

  await M.Counter.create({ _id: 'complaint', seq: 0 });

  return { roles, departments, semesters, categories };
}

async function seedUsers({ roles, departments, semesters }) {
  const pwd = {
    admin: 'Admin@12345',
    hod: 'Hod@12345',
    committee: 'Committee@12345',
    student: 'Student@12345',
  };
  const hash = (p) => bcrypt.hash(p, 12);

  const admin = await M.User.create({
    fullName: 'System Administrator', email: 'admin@university.edu',
    passwordHash: await hash(pwd.admin), roleId: roles.Admin._id, roleName: 'Admin',
    status: 'active', emailVerified: true,
  });
  await M.Profile.create({ userId: admin._id, fullName: admin.fullName });

  const hodDefs = [
    ['Dr. Ayesha Khan', 'hod.cs@university.edu', 'CS'],
    ['Dr. Bilal Ahmed', 'hod.se@university.edu', 'SE'],
  ];
  const committeeDefs = [
    ['Ms. Sara Malik', 'committee.cs@university.edu', 'CS'],
    ['Mr. Usman Tariq', 'committee.bba@university.edu', 'BBA'],
    ['Ms. Hira Shah', 'committee.ee@university.edu', 'EE'],
  ];

  const committeeUsers = [];

  for (const [fullName, email, deptCode] of hodDefs) {
    const u = await M.User.create({
      fullName, email, passwordHash: await hash(pwd.hod),
      roleId: roles['Committee HOD']._id, roleName: 'Committee HOD',
      departmentId: departments[deptCode]._id, status: 'active', emailVerified: true,
    });
    await M.Profile.create({ userId: u._id, fullName });
    await M.CommitteeMember.create({ userId: u._id, departmentId: departments[deptCode]._id, designation: 'HOD', isEligible: true, isActive: true, joinedAt: daysAgo(200) });
    committeeUsers.push(u);
  }

  for (const [fullName, email, deptCode] of committeeDefs) {
    const u = await M.User.create({
      fullName, email, passwordHash: await hash(pwd.committee),
      roleId: roles['Committee Member']._id, roleName: 'Committee Member',
      departmentId: departments[deptCode]._id, status: 'active', emailVerified: true,
    });
    await M.Profile.create({ userId: u._id, fullName });
    await M.CommitteeMember.create({ userId: u._id, departmentId: departments[deptCode]._id, designation: 'Member', isEligible: true, isActive: true, joinedAt: daysAgo(150) });
    committeeUsers.push(u);
  }

  const studentDefs = [
    ['Zehra Fatima', 'zehra.student@university.edu', 'ML.ISB-FA26/BSCS-101', 'CS', 'F2026'],
    ['Maha Noor', 'maha.student@university.edu', 'ML.ISB-FA26/BSSE-102', 'SE', 'F2026'],
    ['Ahmed Raza', 'ahmed.student@university.edu', 'ML.ISB-FA26/BBA-103', 'BBA', 'F2026'],
    ['Fatima Ali', 'fatima.student@university.edu', 'ML.ISB-FA26/BSEE-104', 'EE', 'F2026'],
    ['Hassan Iqbal', 'hassan.student@university.edu', 'ML.ISB-FA26/BSENG-105', 'ENG', 'F2026'],
    ['Komal Shahid', 'komal.student@university.edu', 'ML.ISB-FA26/BSMATH-106', 'MATH', 'F2026'],
  ];
  const students = [];
  for (const [fullName, email, registrationNumber, deptCode, semCode] of studentDefs) {
    const u = await M.User.create({
      fullName, email, registrationNumber,
      passwordHash: await hash(pwd.student), roleId: roles.Student._id, roleName: 'Student',
      departmentId: departments[deptCode]._id, semesterId: semesters[semCode]._id,
      status: 'active', emailVerified: true,
    });
    await M.Profile.create({ userId: u._id, fullName });
    await M.Registration.create({ userId: u._id, email, registrationNumber, status: 'completed' });
    await M.ConsentRecord.create({ userId: u._id, type: 'registration', accepted: true });
    students.push(u);
  }

  console.log('\n--- Seeded login credentials (development only) ---');
  console.log('Admin:            admin@university.edu / ' + pwd.admin);
  console.log('Committee HOD:    hod.cs@university.edu / ' + pwd.hod + '  (and hod.se@university.edu)');
  console.log('Committee Member: committee.cs@university.edu / ' + pwd.committee + '  (and 2 more)');
  console.log('Students:         zehra.student@university.edu / ' + pwd.student + '  (and 5 more, see list above)');
  console.log('-----------------------------------------------------\n');

  return { admin, committeeUsers, students };
}

async function makeComplaint({ student, title, description, categoryId, departmentId, semesterId, accusedName, accusedRelationship, witnesses, incidentDaysAgo, immediateSafetyConcern }) {
  const c = await M.Complaint.create({
    studentId: student._id, title, description, categoryId,
    incidentDate: daysAgo(incidentDaysAgo), incidentLocation: 'Main Campus',
    departmentId, semesterId,
    accused: { name: accusedName, relationship: accusedRelationship },
    safeContactMethod: 'Email', confidential: true,
    immediateSafetyConcern: !!immediateSafetyConcern, status: 'Draft',
  });
  if (witnesses && witnesses.length) {
    await M.Witness.insertMany(witnesses.map((w) => ({ complaintId: c._id, name: w.name, contact: w.contact, statement: w.statement })));
  }
  return c;
}

async function submit(c, student) {
  c.referenceNo = await wf.nextReference();
  await wf.changeStatus(c, 'Submitted', student, 'Submitted by student');
  await wf.notifyAdmins('New complaint', c.referenceNo + ' was submitted.', c._id);
  await wf.notify(student._id, 'Complaint submitted', 'Your reference number is ' + c.referenceNo + '.', c._id);
}

async function addEvidence(c, uploader, name, mime) {
  const ev = await M.Evidence.create({
    complaintId: c._id, uploadedBy: uploader._id, originalName: name,
    storedName: Math.random().toString(36).slice(2) + name.slice(name.lastIndexOf('.')),
    mimeType: mime, size: 204800, sha256: crypto.createHash('sha256').update(name).digest('hex'),
  });
  if (mime.startsWith('image/')) {
    await M.EvidenceAnalysis.create({
      evidenceId: ev._id, provider: 'none', result: 'Analysis unavailable',
      limitations: 'No AI-detection provider configured. Results from any provider are indicative only.',
    });
  }
  return ev;
}

async function seedComplaints({ admin, committeeUsers, students, departments, semesters, categories }) {
  const [hodCS, hodSE, memberCS, memberBBA, memberEE] = committeeUsers;
  const [s1, s2, s3, s4, s5, s6] = students;

  // 1) Draft only
  await makeComplaint({
    student: s1, title: 'Unwanted comments during lab session',
    description: 'A classmate kept making unwelcome remarks during lab hours. I have not yet decided whether to formally submit this.',
    categoryId: categories['Verbal Harassment']._id, departmentId: departments.CS._id, semesterId: semesters.F2026._id,
    accusedName: 'Classmate X', accusedRelationship: 'Fellow student', incidentDaysAgo: 3,
  });

  // 2) Submitted
  const c2 = await makeComplaint({
    student: s2, title: 'Inappropriate messages on group chat',
    description: 'I have been receiving repeated inappropriate messages from a senior student on our class group chat.',
    categoryId: categories['Cyber Harassment']._id, departmentId: departments.SE._id, semesterId: semesters.F2026._id,
    accusedName: 'Senior Student Y', accusedRelationship: 'Senior student', incidentDaysAgo: 5,
  });
  await submit(c2, s2);

  // 3) Rejected
  const c3 = await makeComplaint({
    student: s3, title: 'Disagreement over group project grading',
    description: 'I believe the grading of our group project was unfair, but this may not be a harassment matter.',
    categoryId: categories['Other']._id, departmentId: departments.BBA._id, semesterId: semesters.F2026._id,
    accusedName: 'Course Instructor', accusedRelationship: 'Faculty', incidentDaysAgo: 10,
  });
  await submit(c3, s3);
  await wf.changeStatus(c3, 'Rejected', admin, 'This concern is academic, not a harassment matter. Please contact the academic affairs office.');
  await wf.notify(s3._id, 'Complaint update', 'Your complaint ' + c3.referenceNo + ' is now: Rejected.', c3._id);

  // 4) Under Initial Review
  const c4 = await makeComplaint({
    student: s4, title: 'Repeated unwanted physical proximity',
    description: 'A lab partner keeps standing uncomfortably close despite being asked to stop.',
    categoryId: categories['Physical Harassment']._id, departmentId: departments.EE._id, semesterId: semesters.F2026._id,
    accusedName: 'Lab Partner Z', accusedRelationship: 'Fellow student', incidentDaysAgo: 7,
    witnesses: [{ name: 'Lab Assistant', contact: '0300-1234567', statement: 'Observed the behaviour during two lab sessions.' }],
  });
  await submit(c4, s4);
  await wf.changeStatus(c4, 'Under Initial Review', admin, 'Reviewed by admin');

  // 5) Awaiting Assignment
  const c5 = await makeComplaint({
    student: s5, title: 'Discriminatory remarks in class',
    description: 'A faculty member made discriminatory remarks about my background in front of the class.',
    categoryId: categories['Discrimination']._id, departmentId: departments.ENG._id, semesterId: semesters.F2026._id,
    accusedName: 'Faculty Member A', accusedRelationship: 'Faculty', incidentDaysAgo: 14, immediateSafetyConcern: false,
  });
  await submit(c5, s5);
  await wf.changeStatus(c5, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c5, 'Awaiting Assignment', admin, 'Ready for assignment');

  // 6) Assigned
  const c6 = await makeComplaint({
    student: s6, title: 'Being followed after class repeatedly',
    description: 'A person I do not know has followed me after class on multiple occasions this semester.',
    categoryId: categories['Stalking']._id, departmentId: departments.MATH._id, semesterId: semesters.F2026._id,
    accusedName: 'Unknown individual', accusedRelationship: 'Unknown', incidentDaysAgo: 4, immediateSafetyConcern: true,
  });
  await submit(c6, s6);
  await wf.changeStatus(c6, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c6, 'Awaiting Assignment', admin, 'Ready for assignment');
  c6.assignedTo = memberEE._id;
  await M.Assignment.create({ complaintId: c6._id, assigneeId: memberEE._id, assignedBy: admin._id, active: true });
  await wf.changeStatus(c6, 'Assigned', admin, 'Assigned to ' + memberEE.fullName);
  await wf.notify(memberEE._id, 'New case assigned', 'Case ' + c6.referenceNo + ' has been assigned to you.', c6._id);
  await M.AuditLog.create({ actorId: admin._id, action: 'assign_complaint', targetType: 'Complaint', targetId: c6._id, details: { assigneeId: memberEE._id } });

  // 7) Under Investigation (with evidence + notes)
  const c7 = await makeComplaint({
    student: s1, title: 'Threatening messages after rejecting a request',
    description: 'After declining to share my assignment, I began receiving threatening messages from a classmate.',
    categoryId: categories['Cyber Harassment']._id, departmentId: departments.CS._id, semesterId: semesters.F2026._id,
    accusedName: 'Classmate B', accusedRelationship: 'Fellow student', incidentDaysAgo: 9,
    witnesses: [{ name: 'Roommate', contact: '0301-9876543', statement: 'Saw the messages on the student\'s phone.' }],
  });
  await submit(c7, s1);
  await wf.changeStatus(c7, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c7, 'Awaiting Assignment', admin, 'Ready for assignment');
  c7.assignedTo = memberCS._id;
  await M.Assignment.create({ complaintId: c7._id, assigneeId: memberCS._id, assignedBy: admin._id, active: true });
  await wf.changeStatus(c7, 'Assigned', admin, 'Assigned to ' + memberCS.fullName);
  await wf.changeStatus(c7, 'Under Investigation', memberCS, null);
  await addEvidence(c7, s1, 'screenshot_messages.png', 'image/png');
  await addEvidence(c7, s1, 'incident_report.pdf', 'application/pdf');
  await M.InvestigationNote.create({ complaintId: c7._id, authorId: memberCS._id, note: 'Reviewed submitted screenshots. Scheduling an interview with the accused student.' });

  // 8) Awaiting Student Information
  const c8 = await makeComplaint({
    student: s2, title: 'Unwanted attention from a teaching assistant',
    description: 'A teaching assistant has been giving me unwanted personal attention that makes me uncomfortable.',
    categoryId: categories['Sexual Harassment']._id, departmentId: departments.SE._id, semesterId: semesters.F2026._id,
    accusedName: 'Teaching Assistant C', accusedRelationship: 'Teaching assistant', incidentDaysAgo: 12,
  });
  await submit(c8, s2);
  await wf.changeStatus(c8, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c8, 'Awaiting Assignment', admin, 'Ready for assignment');
  c8.assignedTo = hodSE._id;
  await M.Assignment.create({ complaintId: c8._id, assigneeId: hodSE._id, assignedBy: admin._id, active: true });
  await wf.changeStatus(c8, 'Assigned', admin, 'Assigned to ' + hodSE.fullName);
  await wf.changeStatus(c8, 'Under Investigation', hodSE, null);
  await M.InvestigationNote.create({ complaintId: c8._id, authorId: hodSE._id, note: 'Need more details on specific dates of the incidents before proceeding.' });
  await wf.changeStatus(c8, 'Awaiting Student Information', hodSE, null);
  await wf.notify(c8.studentId, 'More information needed', 'The committee needs more information about your complaint.', c8._id);

  // 9) Awaiting Committee Decision (with case review)
  const c9 = await makeComplaint({
    student: s3, title: 'Mocking comments about my accent',
    description: 'Several classmates repeatedly mock my accent during group activities despite being asked to stop.',
    categoryId: categories['Bullying']._id, departmentId: departments.BBA._id, semesterId: semesters.F2026._id,
    accusedName: 'Group of classmates', accusedRelationship: 'Fellow students', incidentDaysAgo: 20,
  });
  await submit(c9, s3);
  await wf.changeStatus(c9, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c9, 'Awaiting Assignment', admin, 'Ready for assignment');
  c9.assignedTo = memberBBA._id;
  await M.Assignment.create({ complaintId: c9._id, assigneeId: memberBBA._id, assignedBy: admin._id, active: true });
  await wf.changeStatus(c9, 'Assigned', admin, 'Assigned to ' + memberBBA.fullName);
  await wf.changeStatus(c9, 'Under Investigation', memberBBA, null);
  await M.InvestigationNote.create({ complaintId: c9._id, authorId: memberBBA._id, note: 'Spoke with three witnesses who confirmed the pattern of behaviour.' });
  await wf.changeStatus(c9, 'Awaiting Committee Decision', memberBBA, null);
  await M.CaseReview.create({ complaintId: c9._id, reviewerId: memberBBA._id, findings: 'Multiple witnesses confirmed repeated mocking behaviour over several weeks.', recommendation: 'Formal warning and mandatory sensitivity training for involved students.' });

  // 10) Resolved
  const c10 = await makeComplaint({
    student: s4, title: 'Offensive posts targeting me on social media',
    description: 'A fellow student has been posting offensive content about me on a public social media page.',
    categoryId: categories['Cyber Harassment']._id, departmentId: departments.EE._id, semesterId: semesters.F2026._id,
    accusedName: 'Fellow Student D', accusedRelationship: 'Fellow student', incidentDaysAgo: 30,
  });
  await submit(c10, s4);
  await wf.changeStatus(c10, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c10, 'Awaiting Assignment', admin, 'Ready for assignment');
  c10.assignedTo = hodCS._id;
  await M.Assignment.create({ complaintId: c10._id, assigneeId: hodCS._id, assignedBy: admin._id, active: true });
  await wf.changeStatus(c10, 'Assigned', admin, 'Assigned to ' + hodCS.fullName);
  await wf.changeStatus(c10, 'Under Investigation', hodCS, null);
  await M.InvestigationNote.create({ complaintId: c10._id, authorId: hodCS._id, note: 'Confirmed the posts and identified the responsible student.' });
  await wf.changeStatus(c10, 'Awaiting Committee Decision', hodCS, null);
  await M.CaseReview.create({ complaintId: c10._id, reviewerId: hodCS._id, findings: 'Posts were confirmed and traced to the accused student.', recommendation: 'Content removal, written apology, and disciplinary probation.' });
  await wf.changeStatus(c10, 'Resolved', hodCS, null);
  await wf.notify(c10.studentId, 'Complaint update', 'Your complaint ' + c10.referenceNo + ' is now: Resolved.', c10._id);

  // 11) Closed
  const c11 = await makeComplaint({
    student: s5, title: 'Verbal abuse during a study group session',
    description: 'A study group member shouted insults at me after a disagreement about the project direction.',
    categoryId: categories['Verbal Harassment']._id, departmentId: departments.ENG._id, semesterId: semesters.F2026._id,
    accusedName: 'Study Group Member E', accusedRelationship: 'Fellow student', incidentDaysAgo: 45,
  });
  await submit(c11, s5);
  await wf.changeStatus(c11, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c11, 'Awaiting Assignment', admin, 'Ready for assignment');
  c11.assignedTo = memberEE._id;
  await M.Assignment.create({ complaintId: c11._id, assigneeId: memberEE._id, assignedBy: admin._id, active: true });
  await wf.changeStatus(c11, 'Assigned', admin, 'Assigned to ' + memberEE.fullName);
  await wf.changeStatus(c11, 'Under Investigation', memberEE, null);
  await wf.changeStatus(c11, 'Awaiting Committee Decision', memberEE, null);
  await M.CaseReview.create({ complaintId: c11._id, reviewerId: memberEE._id, findings: 'Both parties acknowledged the heated exchange; no further evidence of a pattern.', recommendation: 'Informal mediation session, no formal action needed.' });
  await wf.changeStatus(c11, 'Resolved', memberEE, null);
  await wf.changeStatus(c11, 'Closed', admin, null);

  // 12) Reopened
  const c12 = await makeComplaint({
    student: s6, title: 'Continued unwanted contact after prior warning',
    description: 'Despite a previous warning, I am again receiving unwanted messages from the same individual.',
    categoryId: categories['Stalking']._id, departmentId: departments.MATH._id, semesterId: semesters.F2026._id,
    accusedName: 'Previously Warned Individual', accusedRelationship: 'Fellow student', incidentDaysAgo: 60,
  });
  await submit(c12, s6);
  await wf.changeStatus(c12, 'Under Initial Review', admin, 'Reviewed by admin');
  await wf.changeStatus(c12, 'Awaiting Assignment', admin, 'Ready for assignment');
  c12.assignedTo = hodCS._id;
  await M.Assignment.create({ complaintId: c12._id, assigneeId: hodCS._id, assignedBy: admin._id, active: true });
  await wf.changeStatus(c12, 'Assigned', admin, 'Assigned to ' + hodCS.fullName);
  await wf.changeStatus(c12, 'Under Investigation', hodCS, null);
  await wf.changeStatus(c12, 'Awaiting Committee Decision', hodCS, null);
  await M.CaseReview.create({ complaintId: c12._id, reviewerId: hodCS._id, findings: 'Initial review found insufficient evidence at the time.', recommendation: 'Case closed pending further evidence.' });
  await wf.changeStatus(c12, 'Resolved', hodCS, null);
  await wf.changeStatus(c12, 'Closed', admin, null);
  await wf.changeStatus(c12, 'Reopened', admin, 'New evidence submitted by the student; reopening for further investigation.');
  await wf.notify(c12.studentId, 'Complaint update', 'Your complaint ' + c12.referenceNo + ' is now: Reopened.', c12._id);

  console.log('Seeded 12 complaints spanning every workflow status.');
}

(async () => {
  await connectDB();
  await wipe();
  const refData = await seedReferenceData();
  const people = await seedUsers(refData);
  await seedComplaints(Object.assign({}, people, refData));
  console.log('\nDatabase seeding complete.');
})()
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect().catch(() => {});
  });