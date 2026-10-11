// Email / password login, sign up and password reset (Firebase Auth).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool isSignUp = false;
  bool busy = false;
  bool hidePassword = true;
  String error = '';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  String messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is wrong.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
      }
      // AuthGate opens the app automatically.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = messageFor(e));
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> resetPassword() async {
    final mail = email.text.trim();
    if (mail.isEmpty) {
      setState(() => error = 'Write your email first, then tap "Forgot password".');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      if (mounted) toast(context, 'Password reset link sent to $mail');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FadeSlideIn(
                      index: 0,
                      child: Center(child: Floating(child: AppLogo(size: 84))),
                    ),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      index: 1,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          isSignUp ? 'Create your account' : 'Welcome back',
                          key: ValueKey(isSignUp),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeSlideIn(
                      index: 2,
                      child: Text('Quotations & invoices in one place', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      index: 3,
                      child: TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 4,
                      child: TextFormField(
                        controller: password,
                        obscureText: hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => hidePassword = !hidePassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: isSignUp
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextFormField(
                                controller: confirmPassword,
                                obscureText: hidePassword,
                                decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                                validator: (v) => (isSignUp && v != password.text) ? 'Passwords do not match' : null,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    if (!isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: resetPassword, child: const Text('Forgot password?')),
                      ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: error.isEmpty
                          ? const SizedBox(width: double.infinity, height: 8)
                          : Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                              child: Text(error, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                            ),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      index: 5,
                      child: ColorButton(
                        text: isSignUp ? 'Create account' : 'Sign in',
                        icon: isSignUp ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
                        color: isSignUp ? Palette.green : Palette.blue,
                        busy: busy,
                        onPressed: submit,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() {
                        isSignUp = !isSignUp;
                        error = '';
                      }),
                      child: Text(isSignUp ? 'Already have an account? Sign in' : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
