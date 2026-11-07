import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth.dart';
import '../bluetooth_printer.dart';
import '../layout.dart';
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
  bool testingPrinter = false;
  String error = '';
  String profileMessage = '';
  String passwordMessage = '';
  String printerMessage = '';
  String printerName = '';
  bool printerConnected = false;
  List<PairedPrinter> pairedPrinters = const [];

  @override
  void initState() {
    super.initState();
    previewUrl = context.read<AuthController>().user?.avatarUrl ?? '';
    loadPrinter();
  }

  Future<void> loadPrinter() async {
    if (!BluetoothPrinter.isSupported) return;
    await BluetoothPrinter.instance.loadSaved();
    List<PairedPrinter> paired = const [];
    var connected = false;
    try {
      paired = await BluetoothPrinter.instance.pairedPrinters();
      connected = await BluetoothPrinter.instance.isConnected;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      printerName = BluetoothPrinter.instance.name;
      printerConnected = connected;
      pairedPrinters = paired;
    });
  }

  Future<void> testPrinter() async {
    setState(() {
      testingPrinter = true;
      error = '';
      printerMessage = '';
    });
    try {
      await BluetoothPrinter.instance.printTest();
      if (!mounted) return;
      setState(() {
        printerName = BluetoothPrinter.instance.name;
        printerConnected = true;
        printerMessage = 'Printed a test ticket to ${BluetoothPrinter.instance.name}.';
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is PrinterException ? err.message : 'Unable to print test ticket.');
    } finally {
      if (mounted) setState(() => testingPrinter = false);
    }
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final profileCard = JaPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                          // const SizedBox(height: 12),
                          // if (profileMessage.isNotEmpty) ...[JaAlert(profileMessage, success: true), const SizedBox(height: 12)],
                          // Row(
                          //   children: [
                          //     if (avatarFile != null && !removeAvatar)
                          //       ClipOval(child: Image.file(avatarFile!, width: 88, height: 88, fit: BoxFit.cover))
                          //     else
                          //       ProductPhoto(
                          //         name: name.text,
                          //         hasImage: previewUrl.isNotEmpty && !removeAvatar,
                          //         imageUrl: previewUrl,
                          //         size: 88,
                          //         radius: 44,
                          //       ),
                          //     const SizedBox(width: 12),
                          //     Expanded(
                          //       child: Column(
                          //         crossAxisAlignment: CrossAxisAlignment.start,
                          //         children: [
                          //           JaButton(
                          //             label: 'Choose photo',
                          //             onPressed: () async {
                          //               final picked = await ImagePicker().pickImage(
                          //                 source: ImageSource.gallery,
                          //                 imageQuality: 85,
                          //               );
                          //               if (picked == null) return;
                          //               setState(() {
                          //                 avatarFile = File(picked.path);
                          //                 previewUrl = picked.path;
                          //                 removeAvatar = false;
                          //               });
                          //             },
                          //           ),
                          //           const SizedBox(height: 6),
                          //           const Text(
                          //             'JPG, PNG, WEBP, or GIF up to 2 MB.',
                          //             style: TextStyle(color: JaColors.muted, fontSize: 12),
                          //           ),
                          //           if (previewUrl.isNotEmpty && !removeAvatar)
                          //             TextButton(
                          //               onPressed: () => setState(() {
                          //                 avatarFile = null;
                          //                 previewUrl = '';
                          //                 removeAvatar = true;
                          //               }),
                          //               child: const Text('Remove photo', style: TextStyle(color: JaColors.danger)),
                          //             ),
                          //         ],
                          //       ),
                          //     ),
                          //   ],
                          // ),
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
                    );
                    final passwordCard = JaPanel(
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
                    );
                    if (isCompact(context)) {
                      return Column(
                        children: [
                          profileCard,
                          const SizedBox(height: 16),
                          passwordCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: profileCard),
                        const SizedBox(width: 16),
                        Expanded(child: passwordCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                JaPanel(child: _printerPanel()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _printerPanel() {
    final status = !BluetoothPrinter.isSupported
        ? 'Bluetooth printing runs on the Android / Windows tablet app, not in Chrome.'
        : printerConnected && printerName.isNotEmpty
            ? 'Connected to $printerName. Receipts and barcodes print here with no printer picker.'
            : printerName.isNotEmpty
                ? 'Will print to $printerName over Bluetooth. Pair it in system Bluetooth settings if it is off.'
                : 'Pair the printer in Bluetooth settings, allow Nearby devices, then tap PT265_DAD5 below if needed.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt printer', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (printerMessage.isNotEmpty) ...[JaAlert(printerMessage, success: true), const SizedBox(height: 8)],
        Text(status, style: const TextStyle(color: JaColors.muted, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            JaButton(
              label: testingPrinter ? 'Printing...' : 'Test print',
              primary: true,
              icon: Icons.print,
              onPressed: !BluetoothPrinter.isSupported || testingPrinter ? null : testPrinter,
            ),
            JaButton(
              label: 'Refresh',
              onPressed: !BluetoothPrinter.isSupported ? null : loadPrinter,
            ),
            if (printerName.isNotEmpty)
              Text(
                printerConnected ? 'Bluetooth · $printerName' : printerName,
                style: const TextStyle(color: JaColors.inkSoft, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        if (pairedPrinters.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Tap PT265_DAD5 once. After that, Print sends to it with no picker.',
            style: TextStyle(color: JaColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pairedPrinters
                .map(
                  (item) => OutlinedButton(
                    style: printerName == item.name
                        ? OutlinedButton.styleFrom(
                            foregroundColor: JaColors.forest,
                            side: const BorderSide(color: JaColors.forest),
                          )
                        : null,
                    onPressed: () async {
                      try {
                        await BluetoothPrinter.instance.usePrinter(item);
                        if (!mounted) return;
                        setState(() {
                          printerName = item.name;
                          printerConnected = true;
                          printerMessage = 'Using ${item.name}.';
                          error = '';
                        });
                      } catch (err) {
                        if (!mounted) return;
                        setState(() {
                          error = err is PrinterException ? err.message : 'Unable to use that printer.';
                        });
                      }
                    },
                    child: Text(item.name.isEmpty ? item.mac : item.name),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
