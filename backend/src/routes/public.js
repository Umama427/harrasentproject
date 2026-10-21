// Reference data used by dropdowns (registration needs these before login).
const router = require('express').Router();
const { Department, Semester, Category, Gender, Policy, SupportService, Process } = require('../models');

const list = (Model, filter = {}, sort = { name: 1 }) => async (req, res, next) => {
  try { res.json({ success: true, data: await Model.find(filter).sort(sort) }); } catch (e) { next(e); }
};

router.get('/departments', list(Department));
router.get('/semesters', list(Semester, {}, { number: 1 }));
router.get('/categories', list(Category, { isActive: { $ne: false } }));
router.get('/genders', list(Gender));
router.get('/policies', list(Policy, {}, { createdAt: -1 }));
router.get('/support-services', list(SupportService));
router.get('/processes', list(Process, {}, { createdAt: 1 }));

module.exports = router;
