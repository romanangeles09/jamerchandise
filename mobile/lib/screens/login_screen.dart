import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final pincode = TextEditingController();
  bool adminMode = false;
  bool showPassword = false;
  bool showPincode = false;
  bool submitting = false;
  String error = '';
  List<NamedRef> staff = [];
  String? userId;

  @override
  void initState() {
    super.initState();
    loadStaff();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    pincode.dispose();
    super.dispose();
  }

  Future<void> loadStaff() async {
    try {
      final next = await context.read<ApiClient>().staff();
      if (!mounted) return;
      setState(() => staff = next);
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load staff.');
    }
  }

  void switchMode() {
    setState(() {
      adminMode = !adminMode;
      error = '';
      showPassword = false;
      showPincode = false;
      password.clear();
      pincode.clear();
    });
  }

  Future<void> submit() async {
    setState(() {
      error = '';
      submitting = true;
    });
    try {
      final auth = context.read<AuthController>();
      if (adminMode) {
        await auth.login(email.text, password.text);
      } else {
        await auth.loginWithPin(userId: userId ?? '', pincode: pincode.text);
      }
    } catch (err) {
      setState(() {
        error = err is ApiException
            ? err.message
            : adminMode
            ? 'Invalid email/username or password.'
            : 'Invalid PIN.';
      });
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 11,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF12211B), Color(0xFF1B3A2F)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 32, 32, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x66E8C39A)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'EST. WHOLESALE & RETAIL COUNTER',
                        style: TextStyle(color: JaColors.gold, fontSize: 12, letterSpacing: 0.8),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'JA Merchandise',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: const Color(0xFFF7EFE3),
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'A simple point of sale for bulk and walk-in sales, stock, and the daily counter.',
                      style: TextStyle(color: Color(0xFFD9CBB8), fontSize: 18, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 32).clamp(0, double.infinity),
                      maxWidth: 420,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: JaColors.card,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Color(0x1F12211B), blurRadius: 40, offset: Offset(0, 18))],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminMode ? 'SUPER ADMIN LOGIN' : 'STAFF LOGIN',
                              style: const TextStyle(
                                color: JaColors.copper,
                                letterSpacing: 2,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              adminMode ? 'Sign in as Super Admin' : 'Sign in to the register',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
                            if (adminMode) ...[
                              FieldLabel(
                                label: 'Email / Username',
                                child: TextField(
                                  controller: email,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(hintText: 'Super Admin email or username'),
                                  onSubmitted: (_) => submit(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FieldLabel(
                                label: 'Password',
                                child: TextField(
                                  controller: password,
                                  obscureText: !showPassword,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => showPassword = !showPassword),
                                      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                                    ),
                                  ),
                                  onSubmitted: (_) => submit(),
                                ),
                              ),
                            ] else ...[
                              FieldLabel(
                                label: 'Staff',
                                child: DropdownButtonFormField<String>(
                                  initialValue: userId,
                                  hint: Text(staff.isEmpty ? 'No staff with a PIN yet' : 'Select staff'),
                                  items: staff
                                      .map((member) => DropdownMenuItem(value: member.id, child: Text(member.name)))
                                      .toList(),
                                  onChanged: staff.isEmpty ? null : (value) => setState(() => userId = value),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FieldLabel(
                                label: 'PIN code',
                                child: TextField(
                                  controller: pincode,
                                  obscureText: !showPincode,
                                  keyboardType: TextInputType.number,
                                  maxLength: 8,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    hintText: '8 digits',
                                    counterText: '',
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => showPincode = !showPincode),
                                      icon: Icon(showPincode ? Icons.visibility_off : Icons.visibility),
                                    ),
                                  ),
                                  onSubmitted: (_) => submit(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            JaButton(
                              label: submitting ? 'Signing in...' : 'Enter POS',
                              primary: true,
                              expanded: true,
                              onPressed: submitting ? null : submit,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: switchMode,
                              style: TextButton.styleFrom(
                                foregroundColor: JaColors.copperDark,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                              ),
                              child: Text(adminMode ? 'Back to staff login' : 'Super Admin login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
