import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_sync.dart';
import '../../providers/settings_provider.dart';

/// Sign in or create an account, so progress follows the user across devices
/// and the website. Studying works without this.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _registering = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = _registering
        ? await auth.register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          )
        : await auth.login(email: _email.text.trim(), password: _password.text);

    if (!mounted || !ok) return;

    // Keep anything studied offline, then take the server's view.
    final version = context.read<SettingsProvider>().testVersion;
    await context.read<ProgressSync>().syncAll(version);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signed in as ${auth.user?.label ?? ''}')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_registering ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_sync_rounded,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'An account saves your progress, study plan and test '
                          'history, and keeps them in step with the website. '
                          'Studying works fine without one.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_registering) ...[
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your email.';
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  helperText: _registering
                      ? 'At least 8 characters, with a letter and a digit.'
                      : null,
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Enter your password.';
                  if (_registering && value.length < 8) {
                    return 'Use at least 8 characters.';
                  }
                  return null;
                },
              ),

              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: auth.busy ? null : _submit,
                icon: auth.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_registering ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: auth.busy
                    ? null
                    : () => setState(() {
                        _registering = !_registering;
                        context.read<AuthProvider>().clearError();
                      }),
                child: Text(
                  _registering
                      ? 'I already have an account'
                      : 'Create a new account',
                ),
              ),

              if (!ApiConfig.isConfigured) ...[
                const SizedBox(height: 16),
                Text(
                  'No backend is configured for this build. Run with '
                  '--dart-define=API_BASE_URL=http://10.0.2.2:5199 to point the '
                  'app at a local server.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
