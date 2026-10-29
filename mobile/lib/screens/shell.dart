import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../access.dart';
import '../auth.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'cutoff_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'transactions_screen.dart';
import 'users_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late String page;
  bool collapsed = false;
  final posScreen = const PosScreen();

  @override
  void initState() {
    super.initState();
    page = firstAllowedPage(context.read<AuthController>().user);
  }

  IconData iconFor(String id) {
    return switch (id) {
      'dashboard' => Icons.space_dashboard_outlined,
      'transactions' => Icons.receipt_long_outlined,
      'pos' => Icons.shopping_cart_outlined,
      'cutoff' => Icons.assignment_turned_in_outlined,
      'inventory' => Icons.inventory_2_outlined,
      'users' => Icons.group_outlined,
      _ => Icons.settings_outlined,
    };
  }

  Widget screenFor(String id) {
    return switch (id) {
      'dashboard' => const DashboardScreen(),
      'transactions' => const TransactionsScreen(),
      'pos' => posScreen,
      'cutoff' => const CutoffScreen(),
      'inventory' => const InventoryScreen(),
      'users' => const UsersScreen(),
      _ => const AccountScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final items = accessPages.where((item) => hasAccess(user, item.id)).toList();
    if (!hasAccess(user, page) && items.isNotEmpty) {
      page = items.first.id;
    }

    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: collapsed ? 88 : 260,
            color: JaColors.ink,
            padding: EdgeInsets.fromLTRB(collapsed ? 10 : 18, 24, collapsed ? 10 : 18, 18),
            child: Column(
              crossAxisAlignment: collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                if (collapsed)
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: JaColors.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'JA',
                      style: TextStyle(color: JaColors.ink, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: JaColors.gold,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'JA',
                          style: TextStyle(color: JaColors.ink, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'JA Merchandise',
                              style: TextStyle(color: Color(0xFFEFE6D8), fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Wholesale & Retail POS',
                              style: TextStyle(color: Color(0xFFB7AA98), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: items.map((item) {
                      final active = page == item.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Tooltip(
                          message: item.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => page = item.id),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: active ? const Color(0xFF1F3A30) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                                children: [
                                  Icon(iconFor(item.id), size: 18, color: active ? Colors.white : const Color(0xFFD7CCBE)),
                                  if (!collapsed) ...[
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        item.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: active ? Colors.white : const Color(0xFFD7CCBE)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (collapsed)
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: JaColors.copper,
                        backgroundImage: user?.avatarUrl.isNotEmpty == true ? NetworkImage(user!.avatarUrl) : null,
                        child: user?.avatarUrl.isNotEmpty == true
                            ? null
                            : Text(
                                (user?.name.isNotEmpty == true ? user!.name.substring(0, 1) : 'J').toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                      ),
                      IconButton(
                        tooltip: 'Log out',
                        onPressed: () => auth.logout(),
                        icon: const Icon(Icons.logout, size: 16, color: JaColors.gold),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: JaColors.copper,
                        backgroundImage: user?.avatarUrl.isNotEmpty == true ? NetworkImage(user!.avatarUrl) : null,
                        child: user?.avatarUrl.isNotEmpty == true
                            ? null
                            : Text(
                                (user?.name.isNotEmpty == true ? user!.name.substring(0, 1) : 'J').toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              user?.role ?? '',
                              style: const TextStyle(color: Color(0xFFB7AA98), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => auth.logout(),
                    icon: const Icon(Icons.logout, size: 16, color: JaColors.gold),
                    label: const Text('Log out', style: TextStyle(color: JaColors.gold)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: JaColors.paper,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TickerMode(
                      enabled: page == 'pos',
                      child: Offstage(
                        offstage: page != 'pos',
                        child: posScreen,
                      ),
                    ),
                    if (page != 'pos') screenFor(page),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
          Positioned(
            top: 34,
            left: (collapsed ? 88 : 260) - 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(
                side: BorderSide(color: Color(0xFFC4B7A4)),
              ),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => collapsed = !collapsed),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                    size: 18,
                    color: JaColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
