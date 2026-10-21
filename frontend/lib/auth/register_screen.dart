import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _reg = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _dept;
  String? _sem;
  bool _consent = false;
  bool _busy = false;
  late Future<List<List<dynamic>>> _lookups;

  @override
  void initState() {
    super.initState();
    _lookups = Future.wait([Api.list('/public/departments'), Api.list('/public/semesters')]);
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    if (_name.text.trim().isEmpty || email.isEmpty || _reg.text.trim().isEmpty || _dept == null || _sem == null) {
      snack(context, 'Please fill in all fields.');
      return;
    }
    if (_pass.text.length < 8) {
      snack(context, 'Password must be at least 8 characters.');
      return;
    }
    if (_pass.text != _pass2.text) {
      snack(context, 'Passwords do not match.');
      return;
    }
    if (!_consent) {
      snack(context, 'Please accept the consent to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.post('/auth/register', {
        'fullName': _name.text.trim(),
        'email': email,
        'registrationNumber': _reg.text.trim(),
        'departmentId': _dept,
        'semesterId': _sem,
        'password': _pass.text,
        'consent': true,
      });
      if (!mounted) return;
      snack(context, 'Registered! Please sign in.');
      Navigator.of(context).pop();
      return;
    } catch (e) {
      if (mounted) snack(context, e.toString()); // includes "already registered" message
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<dynamic>>>(
      future: _lookups,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (s.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text(s.error.toString())));
        final depts = s.data![0];
        final sems = s.data![1];
        return AuthFrame(
          title: 'Create student account',
          subtitle: 'Use your university email.',
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'University email')),
            const SizedBox(height: 12),
            TextField(controller: _reg, decoration: const InputDecoration(labelText: 'Registration number')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dept,
              decoration: const InputDecoration(labelText: 'Department'),
              items: depts.map((d) => DropdownMenuItem(value: d['_id'].toString(), child: Text('${d['name']}'))).toList(),
              onChanged: (v) => setState(() => _dept = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sem,
              decoration: const InputDecoration(labelText: 'Semester'),
              items: sems.map((d) => DropdownMenuItem(value: d['_id'].toString(), child: Text('${d['name']}'))).toList(),
              onChanged: (v) => setState(() => _sem = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 12),
            TextField(controller: _pass2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('I agree to the privacy and confidentiality terms.', style: TextStyle(fontSize: 13)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            FilledButton(onPressed: _busy ? null : _register, child: Text(_busy ? 'Please wait...' : 'Register')),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Already registered? Sign in')),
          ],
        );
      },
    );
  }
}
