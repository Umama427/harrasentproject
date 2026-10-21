const express = require('express');
const helmet = require('helmet');
const cors = require('cors');

const app = express();
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN === '*' || !process.env.CORS_ORIGIN ? true : process.env.CORS_ORIGIN.split(',') }));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (req, res) => res.json({ success: true, message: 'API is running' }));
app.use('/api/public', require('./routes/public'));
app.use('/api/auth', require('./routes/auth'));
app.use('/api/student', require('./routes/student'));
app.use('/api/committee', require('./routes/committee'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/evidence', require('./routes/evidence'));

app.use((req, res) => res.status(404).json({ success: false, message: 'Route not found.' }));
app.use((err, req, res, next) => { // central error handler
  if (process.env.NODE_ENV !== 'production') console.error(err);
  const status = err.status || (err.name === 'ValidationError' ? 400 : err.name === 'MulterError' ? 400 : 500);
  res.status(status).json({ success: false, message: status === 500 ? 'Something went wrong.' : err.message });
});

module.exports = app;
