import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

/// Profile management screen for updating user preferences
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

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
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _loadCurrentProfile() {
    final user = ref.read(userProvider);
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _selectedDialect = user.dialect;
      _selectedDifficulty = user.difficulty;
    }
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final currentUser = ref.read(userProvider);
      if (currentUser == null) {
        throw Exception('User not found');
      }

      final updatedProfile = UserProfile(
        userId: currentUser.userId,
        email: currentUser.email,
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
        dialect: _selectedDialect,
        difficulty: _selectedDifficulty,
        translitStyle: currentUser.translitStyle,
        settings: currentUser.settings,
      );

      await ref.read(authProvider.notifier).updateProfile(updatedProfile);

      setState(() {
        _successMessage = 'Profile updated successfully';
      });

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
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

  Future<void> _handleLogout() async {
    final shouldLogout = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authProvider.notifier).logout();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
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
            scrollController: FixedExtentScrollController(
              initialItem: _dialects.indexWhere(
                (d) => d['value'] == _selectedDialect,
              ),
            ),
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
            scrollController: FixedExtentScrollController(
              initialItem: _difficulties.indexWhere(
                (d) => d['value'] == _selectedDifficulty,
              ),
            ),
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
    final user = ref.watch(userProvider);
    final authError = ref.watch(authErrorProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Profile'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _handleLogout,
          child: const Icon(
            CupertinoIcons.square_arrow_right,
            color: CupertinoColors.systemRed,
          ),
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

                // Profile header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.person_fill,
                          size: 40,
                          color: CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.email ?? 'User Email',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.displayName ?? 'No display name',
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
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
                      controller: _displayNameController,
                      prefix: const Icon(
                        CupertinoIcons.person,
                        color: CupertinoColors.systemGrey,
                      ),
                      placeholder: 'Display name',
                      textInputAction: TextInputAction.done,
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
                      prefix: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.globe,
                            color: CupertinoColors.systemGrey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Dialect'),
                        ],
                      ),
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
                      prefix: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.chart_bar,
                            color: CupertinoColors.systemGrey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Difficulty'),
                        ],
                      ),
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
                if (_errorMessage != null || authError != null) ...[
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
                            _errorMessage ?? authError!,
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

                // Success message
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: CupertinoColors.systemGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.checkmark_circle,
                          color: CupertinoColors.systemGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: CupertinoColors.systemGreen,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Update button
                CupertinoButton.filled(
                  onPressed: _isLoading ? null : _handleUpdateProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          ),
                        )
                      : const Text(
                          'Update Profile',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 40),

                // App info section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Lebanese Arabic Translator',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}