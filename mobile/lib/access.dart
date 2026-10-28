import 'models.dart';

class AccessPage {
  const AccessPage({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final String icon;
}

const accessPages = [
  AccessPage(id: 'dashboard', label: 'Dashboard', icon: 'dashboard'),
  AccessPage(id: 'transactions', label: 'Transactions', icon: 'receipt'),
  AccessPage(id: 'pos', label: 'POS', icon: 'cart'),
  AccessPage(id: 'cutoff', label: 'Cutoff', icon: 'cutoff'),
  AccessPage(id: 'inventory', label: 'Inventory', icon: 'package'),
  AccessPage(id: 'users', label: 'User Access', icon: 'users'),
  AccessPage(id: 'account', label: 'Account Setting', icon: 'settings'),
];

bool hasAccess(User? user, String page) {
  if (user == null) return false;
  if (user.role == 'SuperAdmin') return true;
  return user.access.contains(page);
}

String firstAllowedPage(User? user) {
  final page = accessPages.where((item) => hasAccess(user, item.id)).firstOrNull;
  return page?.id ?? 'pos';
}
