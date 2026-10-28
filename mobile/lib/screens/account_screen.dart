import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import '../widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final name = TextEditingController(text: context.read<AuthController>().user?.name ?? '');
  late final email = TextEditingController(text: context.read<AuthController>().user?.email ?? '');
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  File? avatarFile;
  String previewUrl = '';
  bool removeAvatar = false;
  bool saving = false;
  String error = '';
  String profileMessage = '';
  String passwordMessage = '';

  @override
  void initState() {
    super.initState();
    previewUrl = context.read<AuthController>().user?.avatarUrl ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    setState(() {
      saving = true;
      error = '';
      profileMessage = '';
    });
    try {
      await context.read<AuthController>().saveProfile(
        name: name.text,
        email: email.text,
        image: avatarFile,
        removeImage: removeAvatar,
      );
      if (!mounted) return;
      setState(() {
        avatarFile = null;
        removeAvatar = false;
        previewUrl = context.read<AuthController>().user?.avatarUrl ?? '';
        profileMessage = 'Profile saved.';
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to save profile.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> savePassword() async {
    setState(() {
      error = '';
      passwordMessage = '';
    });
    try {
      await context.read<ApiClient>().updatePassword(
        currentPassword: currentPassword.text,
        newPassword: newPassword.text,
      );
      currentPassword.clear();
      newPassword.clear();
      if (!mounted) return;
      setState(() => passwordMessage = 'Password updated.');
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to update password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(eyebrow: 'Your account', title: 'Account Setting'),
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: JaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (profileMessage.isNotEmpty) ...[JaAlert(profileMessage, success: true), const SizedBox(height: 12)],
                      Row(
                        children: [
                          if (avatarFile != null && !removeAvatar)
                            ClipOval(child: Image.file(avatarFile!, width: 88, height: 88, fit: BoxFit.cover))
                          else
                            ProductPhoto(
                              name: name.text,
                              hasImage: previewUrl.isNotEmpty && !removeAvatar,
                              imageUrl: previewUrl,
                              size: 88,
                              radius: 44,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                JaButton(
                                  label: 'Choose photo',
                                  onPressed: () async {
                                    final picked = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 85,
                                    );
                                    if (picked == null) return;
                                    setState(() {
                                      avatarFile = File(picked.path);
                                      previewUrl = picked.path;
                                      removeAvatar = false;
                                    });
                                  },
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'JPG, PNG, WEBP, or GIF up to 2 MB.',
                                  style: TextStyle(color: JaColors.muted, fontSize: 12),
                                ),
                                if (previewUrl.isNotEmpty && !removeAvatar)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      avatarFile = null;
                                      previewUrl = '';
                                      removeAvatar = true;
                                    }),
                                    child: const Text('Remove photo', style: TextStyle(color: JaColors.danger)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FieldLabel(label: 'Full name', child: TextField(controller: name)),
                      const SizedBox(height: 12),
                      FieldLabel(label: 'Email / Username', child: TextField(controller: email)),
                      const SizedBox(height: 12),
                      FieldLabel(
                        label: 'Role',
                        child: InputDecorator(
                          decoration: const InputDecoration(),
                          child: Text(user?.role ?? ''),
                        ),
                      ),
                      const SizedBox(height: 16),
                      JaButton(
                        label: saving ? 'Saving...' : 'Save profile',
                        primary: true,
                        onPressed: saving ? null : saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: JaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Password', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (passwordMessage.isNotEmpty) ...[
                        JaAlert(passwordMessage, success: true),
                        const SizedBox(height: 12),
                      ],
                      FieldLabel(
                        label: 'Current password',
                        child: TextField(controller: currentPassword, obscureText: true),
                      ),
                      const SizedBox(height: 12),
                      FieldLabel(
                        label: 'New password',
                        child: TextField(controller: newPassword, obscureText: true),
                      ),
                      const SizedBox(height: 16),
                      JaButton(label: 'Update password', primary: true, onPressed: savePassword),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
