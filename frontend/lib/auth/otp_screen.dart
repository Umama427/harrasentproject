import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';
import 'login_screen.dart';
import '../student/student_panel.dart';
import '../committee/committee_panel.dart';
import '../admin/admin_panel.dart';

class OtpScreen extends StatefulWidget {
  final String challengeId;
  final String email;
  const OtpScreen({super.key, required this.challengeId, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otp = TextEditingController();
  bool _busy = false;

  Future<void> _verify() async {
    if (_otp.text.trim().length != 6) {
      snack(context, 'Enter the 6-digit code.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.post('/auth/verify-otp', {'challengeId': widget.challengeId, 'otp': _otp.text.trim()});
      Api.token = r['data']['token'] as String;
      Api.user = Map<String, dynamic>.from(r['data']['user'] as Map);
      final role = Api.user!['role'];
      final Widget home = role == 'Admin'
          ? const AdminPanel()
          : role == 'Student'
              ? const StudentPanel()
              : const CommitteePanel();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => home), (r) => false);
      return;
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Enter verification code',
      subtitle: 'We sent a 6-digit code to ${widget.email}. It expires in 5 minutes.',
      children: [
        TextField(
          controller: _otp,
          maxLength: 6,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, letterSpacing: 8),
          onSubmitted: (_) => _verify(),
          decoration: const InputDecoration(counterText: ''),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _verify, child: Text(_busy ? 'Checking...' : 'Verify and sign in')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to sign in')),
      ],
    );
  }
}
