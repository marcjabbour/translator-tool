import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Registration screen with Cupertino design for new user signup
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  String _selectedDialect = 'lebanese';
  String _selectedDifficulty = 'beginner';

  final List<Map<String, String>> _dialects = [
    {'value': 'lebanese', 'label': 'Lebanese'},
    {'value': 'egyptian', 'label': 'Egyptian'},
    {'value': 'gulf', 'label': 'Gulf'},
    {'value': 'levantine', 'label': 'Levantine'},
  ];

  final List<Map<String, String>> _difficulties = [
    {'value': 'beginner', 'label': 'Beginner'},
    {'value': 'intermediate', 'label': 'Intermediate'},
    {'value': 'advanced', 'label': 'Advanced'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        dialect: _selectedDialect,
        difficulty: _selectedDifficulty,
      );

      if (mounted) {
        // Navigate to main app
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDialectPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoPicker(
            magnification: 1.22,
            squeeze: 1.2,
            useMagnifier: true,
            itemExtent: 32,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedDialect = _dialects[index]['value']!;
              });
            },
            children: _dialects
                .map((dialect) => Center(child: Text(dialect['label']!)))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showDifficultyPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoPicker(
            magnification: 1.22,
            squeeze: 1.2,
            useMagnifier: true,
            itemExtent: 32,
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedDifficulty = _difficulties[index]['value']!;
              });
            },
            children: _difficulties
                .map((difficulty) => Center(child: Text(difficulty['label']!)))
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Create Account'),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Welcome text
                const Text(
                  'Join us and start learning!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.label,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your account to access personalized Lebanese Arabic lessons',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Personal Information
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 12),

                CupertinoFormSection.insetGrouped(
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _emailController,
                      prefix: const Icon(
                        CupertinoIcons.mail,
                        color: CupertinoColors.systemGrey,
                      ),
                      placeholder: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    CupertinoTextFormFieldRow(
                      controller: _displayNameController,
                      prefix: const Icon(
                        CupertinoIcons.person,
                        color: CupertinoColors.systemGrey,
                      ),
                      placeholder: 'Display name (optional)',
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Password Section
                const Text(
                  'Security',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 12),

                CupertinoFormSection.insetGrouped(
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _passwordController,
                      prefix: const Icon(
                        CupertinoIcons.lock,
                        color: CupertinoColors.systemGrey,
                      ),
                      placeholder: 'Password',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        child: Icon(
                          _obscurePassword
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                          color: CupertinoColors.systemGrey,
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                          return 'Password must contain a special character';
                        }
                        return null;
                      },
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _confirmPasswordController,
                      prefix: const Icon(
                        CupertinoIcons.lock_fill,
                        color: CupertinoColors.systemGrey,
                      ),
                      placeholder: 'Confirm password',
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        child: Icon(
                          _obscureConfirmPassword
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                          color: CupertinoColors.systemGrey,
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Learning Preferences
                const Text(
                  'Learning Preferences',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 12),

                CupertinoFormSection.insetGrouped(
                  children: [
                    CupertinoFormRow(
                      prefix: const Text('Dialect'),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showDialectPicker,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dialects.firstWhere(
                                (d) => d['value'] == _selectedDialect,
                              )['label']!,
                              style: const TextStyle(
                                color: CupertinoColors.systemBlue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.chevron_down,
                              size: 16,
                              color: CupertinoColors.systemBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    CupertinoFormRow(
                      prefix: const Text('Difficulty'),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _showDifficultyPicker,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _difficulties.firstWhere(
                                (d) => d['value'] == _selectedDifficulty,
                              )['label']!,
                              style: const TextStyle(
                                color: CupertinoColors.systemBlue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.chevron_down,
                              size: 16,
                              color: CupertinoColors.systemBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: CupertinoColors.systemRed.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: CupertinoColors.systemRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Register button
                CupertinoButton.filled(
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 24),

                // Terms and Privacy (placeholder)
                const Text(
                  'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}