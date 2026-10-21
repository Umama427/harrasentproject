require('dotenv').config();
const nodemailer = require('nodemailer');

(async () => {
  const t = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  try {
    const info = await t.sendMail({
      from: process.env.MAIL_FROM,
      to: process.env.SMTP_USER,
      subject: 'Test email',
      text: 'If you see this, SMTP credentials are correct.',
    });
    console.log('SUCCESS:', info.messageId);
  } catch (e) {
    console.error('FAILED:', e.message);
  }
})();