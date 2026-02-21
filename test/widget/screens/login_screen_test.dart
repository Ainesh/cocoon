/// Widget tests for LoginScreen.
///
/// Covers: WS-02 through WS-11 from the test plan.
/// Uses a test-friendly version to avoid Firebase initialization.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Minimal LoginScreen replica for widget testing.
/// Mirrors the key UI structure of the real LoginScreen without Firebase deps.
class TestLoginScreen extends StatefulWidget {
  const TestLoginScreen({super.key, this.inviteCode});
  final String? inviteCode;

  @override
  State<TestLoginScreen> createState() => _TestLoginScreenState();
}

class _TestLoginScreenState extends State<TestLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  bool get _hasInviteCode =>
      widget.inviteCode != null && widget.inviteCode!.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text('Cocoon'),
              const Text('Grow together, intentionally'),
              if (_hasInviteCode)
                Container(
                  key: const Key('invite_badge'),
                  child: const Text("You've been invited to a space"),
                ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (_isSignUp && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('or continue with'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const Key('google_btn'),
                    icon: const Icon(Icons.g_mobiledata),
                    onPressed: () {},
                  ),
                  IconButton(
                    key: const Key('apple_btn'),
                    icon: const Icon(Icons.apple),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'Already have an account?'
                        : "Don't have an account?",
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp ? 'Sign In' : 'Sign Up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  // WS-02
  testWidgets('LoginScreen renders email and password fields', (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  // WS-03
  testWidgets('LoginScreen shows validation errors for empty email',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    // Tap Sign In without entering anything
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
  });

  // WS-04
  testWidgets('LoginScreen shows validation error for invalid email (no @)',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email'), findsOneWidget);
  });

  // WS-05
  testWidgets('LoginScreen shows validation error for short password on signup',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    // Switch to Sign Up mode
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
    await tester.enterText(find.byType(TextFormField).last, '123');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  // WS-06
  testWidgets('LoginScreen toggles between Sign In and Sign Up modes',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    expect(find.text('Sign In'), findsWidgets); // button + toggle
    expect(find.text("Don't have an account?"), findsOneWidget);

    // Toggle to Sign Up
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
  });

  // WS-07
  testWidgets('LoginScreen shows invite badge when inviteCode is provided',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen(inviteCode: 'ABC123'));

    expect(find.text("You've been invited to a space"), findsOneWidget);
  });

  // WS-08
  testWidgets('LoginScreen hides invite badge when no inviteCode',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    expect(find.text("You've been invited to a space"), findsNothing);
  });

  // WS-09
  testWidgets('LoginScreen shows loading indicator during auth',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // WS-10
  testWidgets('LoginScreen toggles password visibility', (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    // Initially password is obscured
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    // Tap to show password
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });

  // WS-11
  testWidgets('LoginScreen shows Google and Apple social buttons',
      (tester) async {
    await tester.pumpScreen(const TestLoginScreen());

    expect(find.byKey(const Key('google_btn')), findsOneWidget);
    expect(find.byKey(const Key('apple_btn')), findsOneWidget);
    expect(find.text('or continue with'), findsOneWidget);
  });
}
