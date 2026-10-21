const nodemailer = require('nodemailer');

let transport = null;
function getTransport() {
  if (!transport) {
    transport = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: false,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return transport;
}

async function sendOtpEmail(to, otp) {
  if (!process.env.SMTP_HOST) {
    console.log(`[DEV ONLY] OTP for ${to}: ${otp}  (configure SMTP_* in .env to send real emails)`);
    return;
  }
  try {
    const info = await getTransport().sendMail({
      from: process.env.MAIL_FROM,
      to,
      subject: 'Your login code',
      text: `Your verification code is ${otp}. It expires in 5 minutes. If this was not you, ignore this email.`,
    });
    console.log(`[MAIL SENT] OTP email sent to ${to}. messageId=${info.messageId}`);
  } catch (err) {
    console.error(`[MAIL ERROR] Failed to send OTP to ${to}:`, err.message);
    console.log(`[FALLBACK] OTP for ${to}: ${otp}`);
  }
}

module.exports = { sendOtpEmail };