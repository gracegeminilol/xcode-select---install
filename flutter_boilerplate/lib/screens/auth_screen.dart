import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isStudent = true;
  bool _isLoginMode = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final authService = ref.read(authServiceProvider);

    try {
      if (_isLoginMode) {
        await authService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else if (_isStudent) {
        await authService.signUpStudent(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
        );
      } else {
        await authService.signUpResident(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
        );

        final currentUserId = ref.read(supabaseProvider).auth.currentUser?.id;
        if (currentUserId != null) {
          await authService.launchIdentityVerification(userId: currentUserId);
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UIUC Sublease Authentication')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Student (@illinois.edu)')),
              ButtonSegment(value: false, label: Text('Local Resident (ID Verify)')),
            ],
            selected: {_isStudent},
            onSelectionChanged: _isLoginMode
                ? null
                : (selection) => setState(() => _isStudent = selection.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            enabled: !_isLoginMode,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: Text(_isLoginMode ? 'Sign In' : 'Create Account'),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                    _isLoginMode = !_isLoginMode;
                    _error = null;
                  }),
            child: Text(
              _isLoginMode
                  ? 'Need an account? Register'
                  : 'Already have an account? Sign in',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!_isLoginMode && !_isStudent)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Resident accounts remain pending until government ID is verified via Stripe Identity.',
              ),
            ),
        ],
      ),
    );
  }
}
