import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../access.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User> users = [];
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final next = await context.read<ApiClient>().users();
      if (!mounted) return;
      setState(() {
        users = next;
        error = '';
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load users.');
    }
  }

  Future<void> openUser([User? user]) async {
    await showJaDialog(
      context: context,
      title: user == null ? 'New user' : 'Edit user',
      child: _UserForm(user: user, onSaved: load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          eyebrow: 'Staff logins',
          title: 'User Access',
          trailing: JaButton(label: 'Add user', primary: true, onPressed: () => openUser()),
        ),
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        Expanded(
          child: JaPanel(
            child: SingleChildScrollView(
              child: JaTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email / username')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Access')),
                  DataColumn(label: Text('')),
                ],
                rows: users.isEmpty
                    ? const [
                        DataRow(
                          cells: [
                            DataCell(Text('No users yet.')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                          ],
                        ),
                      ]
                    : users
                          .map(
                            (user) => DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(
                                        user.isActive ? 'Active' : 'Disabled',
                                        style: const TextStyle(color: JaColors.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(user.email)),
                                DataCell(Text(user.role)),
                                DataCell(
                                  Text(
                                    accessPages
                                        .where((page) => user.access.contains(page.id))
                                        .map((page) => page.label)
                                        .join(', '),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      TextButton(onPressed: () => openUser(user), child: const Text('Edit')),
                                      if (user.role != 'SuperAdmin')
                                        TextButton(
                                          onPressed: () async {
                                            if (!await confirmAction(context, 'Delete this user?')) return;
                                            if (!context.mounted) return;
                                            try {
                                              await context.read<ApiClient>().deleteUser(user.id);
                                              await load();
                                            } catch (err) {
                                              setState(
                                                () => error = err is ApiException
                                                    ? err.message
                                                    : 'Unable to delete user.',
                                              );
                                            }
                                          },
                                          child: const Text('Delete', style: TextStyle(color: JaColors.danger)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserForm extends StatefulWidget {
  const _UserForm({required this.onSaved, this.user});

  final User? user;
  final Future<void> Function() onSaved;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  late final name = TextEditingController(text: widget.user?.name ?? '');
  late final email = TextEditingController(text: widget.user?.email ?? '');
  final password = TextEditingController();
  final pincode = TextEditingController();
  late String role = widget.user?.role ?? 'Cashier';
  late List<String> access = List<String>.from(widget.user?.access ?? const ['pos', 'cutoff', 'account']);
  bool showPassword = false;
  bool showPincode = false;
  bool saving = false;
  String error = '';

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    pincode.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final pin = pincode.text.trim();
    if ((widget.user == null && pin.length != 8) || (pin.isNotEmpty && pin.length != 8)) {
      setState(() => error = 'PIN code must be 8 digits.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final body = <String, dynamic>{
        'name': name.text,
        'email': email.text,
        'role': role,
        'access': access,
        'isActive': widget.user?.isActive ?? true,
      };
      if (password.text.isNotEmpty) body['password'] = password.text;
      if (pincode.text.isNotEmpty) body['pincode'] = pincode.text;
      await context.read<ApiClient>().saveUser(id: widget.user?.id, body: body);
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => error = err is ApiException ? err.message : 'Unable to save user.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuper = widget.user?.role == 'SuperAdmin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        Row(
          children: [
            Expanded(child: FieldLabel(label: 'Name', child: TextField(controller: name, decoration: const InputDecoration(hintText: 'Cashier 1')))),
            const SizedBox(width: 12),
            Expanded(
              child: FieldLabel(
                label: 'Role',
                child: isSuper
                    ? InputDecorator(
                        decoration: const InputDecoration(),
                        child: const Text('SuperAdmin'),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: role,
                        items: const [
                          DropdownMenuItem(value: 'Cashier', child: Text('Cashier')),
                          DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                        ],
                        onChanged: (value) => setState(() => role = value ?? 'Cashier'),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: 'Email / username',
          child: TextField(controller: email, decoration: const InputDecoration(hintText: 'cashier1')),
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: 'Password',
          child: TextField(
            controller: password,
            obscureText: !showPassword,
            decoration: InputDecoration(
              hintText: widget.user == null ? 'At least 6 characters' : 'Leave blank to keep current',
              suffixIcon: IconButton(
                onPressed: () => setState(() => showPassword = !showPassword),
                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: 'PIN code',
          child: TextField(
            controller: pincode,
            obscureText: !showPincode,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: widget.user == null ? '8 digits' : 'Leave blank to keep current',
              counterText: '',
              suffixIcon: IconButton(
                onPressed: () => setState(() => showPincode = !showPincode),
                icon: Icon(showPincode ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Can access', style: TextStyle(fontWeight: FontWeight.w700)),
        ...accessPages.map(
          (page) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: access.contains(page.id),
            title: Text(page.label),
            onChanged: (_) {
              setState(() {
                access = access.contains(page.id)
                    ? access.where((item) => item != page.id).toList()
                    : [...access, page.id];
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            JaButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            JaButton(label: saving ? 'Saving...' : 'Save user', primary: true, onPressed: saving ? null : save),
          ],
        ),
      ],
    );
  }
}
