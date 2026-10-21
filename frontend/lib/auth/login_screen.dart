import 'package:flutter/material.dart';

import '../api.dart';
import '../models/user_role.dart';
import '../theme.dart';
import '../widgets.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class AuthFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: _GlowCircle(color: teal.withValues(alpha: 0.09), size: 340),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: _GlowCircle(color: navySoft.withValues(alpha: 0.42), size: 400),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: teal.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(color: teal.withValues(alpha: 0.45)),
                            boxShadow: [
                              BoxShadow(
                                color: teal.withValues(alpha: 0.12),
                                blurRadius: 26,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 30,
                            color: teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'NidaaCare',
                        textAlign: TextAlign.center,
                        style: heading(27),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'A safe, confidential space to be heard',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: line),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 34,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(title, style: heading(23)),
                            const SizedBox(height: 7),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            ...children,
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Your information is handled with care.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class RoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign in as',
          style: TextStyle(
            color: brightText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: UserRole.values.map((role) {
            final selected = role == selectedRole;

            return ChoiceChip(
              label: Text(role.label),
              selected: selected,
              onSelected: (_) => onChanged(role),
              selectedColor: teal.withValues(alpha: 0.18),
              backgroundColor: surfaceColor,
              side: BorderSide(
                color: selected ? teal : line,
              ),
              labelStyle: TextStyle(
                color: selected ? teal : muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              avatar: Icon(
                _roleIcon(role),
                size: 17,
                color: selected ? teal : muted,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school_outlined;
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.committee:
        return Icons.groups_outlined;
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      snack(context, 'Enter your email and password.');
      return;
    }

    setState(() => _busy = true);

    try {
      final response = await Api.post(
        '/auth/login',
        {
          'email': _email.text.trim(),
          'password': _password.text,
          'role': _selectedRole.apiValue,
        },
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            challengeId: response['data']['challengeId'].toString(),
            email: _email.text.trim(),
          ),
        ),
      );
    } catch (error) {
      if (mounted) snack(context, error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Welcome back',
      subtitle: 'Choose your portal and sign in securely.',
      children: [
        RoleSelector(
          selectedRole: _selectedRole,
          onChanged: (role) => setState(() => _selectedRole = role),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: const TextStyle(color: brightText),
          decoration: const InputDecoration(
            labelText: 'University email',
            prefixIcon: Icon(Icons.mail_outline, color: muted),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: _hide,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _login(),
          style: const TextStyle(color: brightText),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, color: muted),
            suffixIcon: IconButton(
              tooltip: _hide ? 'Show password' : 'Hide password',
              icon: Icon(
                _hide
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: muted,
              ),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _busy ? null : _login,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: navyDeep,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 19),
            label: Text(_busy ? 'Please wait...' : 'Continue securely'),
          ),
        ),
        if (_selectedRole == UserRole.student) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
            child: const Text('New student? Create an account'),
          ),
        ],
      ],
    );
  }
}