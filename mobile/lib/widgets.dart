import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'money.dart';
import 'models.dart';
import 'receipt.dart';
import 'theme.dart';

class JaButton extends StatelessWidget {
  const JaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.expanded = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool expanded;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Text(label),
      ],
    );
    final button = primary
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: JaColors.forest,
              foregroundColor: Colors.white,
              disabledBackgroundColor: JaColors.forest.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: JaColors.ink,
              side: const BorderSide(color: JaColors.line),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: child,
          );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class JaAlert extends StatelessWidget {
  const JaAlert(this.message, {super.key, this.success = false});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFE7F6EE) : const Color(0xFFFDE8E6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(color: success ? JaColors.ok : JaColors.danger, fontSize: 13),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: JaColors.copper,
                    fontSize: 12,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class JaPanel extends StatelessWidget {
  const JaPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: JaColors.card,
        border: Border.all(color: JaColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return JaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: JaColors.inkSoft),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: JaColors.muted)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          if (hint != null)
            Text(hint!, style: const TextStyle(color: JaColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class SegmentedChoice extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: JaColors.cream,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = option.$1 == value;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(option.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? JaColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  option.$2,
                  style: TextStyle(color: selected ? Colors.white : JaColors.ink),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ChipChoice extends StatelessWidget {
  const ChipChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? JaColors.ink : Colors.white,
            border: Border.all(color: selected ? JaColors.ink : JaColors.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(color: selected ? Colors.white : JaColors.ink, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class ProductPhoto extends StatelessWidget {
  const ProductPhoto({
    super.key,
    required this.name,
    required this.hasImage,
    required this.imageUrl,
    this.size = 44,
    this.radius = 12,
  });

  final String name;
  final bool hasImage;
  final String imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? 'J' : name.substring(0, 1).toUpperCase();
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JaColors.cream,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: JaColors.copperDark,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
    if (!hasImage || imageUrl.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: JaColors.inkSoft, fontSize: 12)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

Future<void> showJaDialog({
  required BuildContext context,
  required String title,
  required Widget child,
  double width = 520,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: JaColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool> confirmAction(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: JaColors.card,
        title: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: JaColors.forest),
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
  return result == true;
}

Future<bool> confirmVoidWithPin(
  BuildContext context, {
  required String itemName,
  required Future<void> Function(String pincode) verify,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _VoidPinDialog(itemName: itemName, verify: verify),
  );
  return result == true;
}

class _VoidPinDialog extends StatefulWidget {
  const _VoidPinDialog({required this.itemName, required this.verify});

  final String itemName;
  final Future<void> Function(String pincode) verify;

  @override
  State<_VoidPinDialog> createState() => _VoidPinDialogState();
}

class _VoidPinDialogState extends State<_VoidPinDialog> {
  final pincode = TextEditingController();
  bool showPin = false;
  bool busy = false;
  String error = '';

  @override
  void dispose() {
    pincode.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final pin = pincode.text.trim();
    if (pin.length != 8) {
      setState(() => error = 'PIN code must be 8 digits.');
      return;
    }
    setState(() {
      error = '';
      busy = true;
    });
    try {
      await widget.verify(pin);
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = err is ApiException ? err.message : 'Invalid Super Admin PIN.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: JaColors.card,
      title: const Text('Void item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter the Super Admin PIN to remove ${widget.itemName} from the cart.'),
          const SizedBox(height: 12),
          if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
          FieldLabel(
            label: 'Super Admin PIN',
            child: TextField(
              controller: pincode,
              obscureText: !showPin,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !busy,
              decoration: InputDecoration(
                hintText: '8 digits',
                counterText: '',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => showPin = !showPin),
                  icon: Icon(showPin ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (!busy && pincode.text.length == 8) submit();
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || pincode.text.length != 8 ? null : submit,
          style: FilledButton.styleFrom(backgroundColor: JaColors.forest),
          child: Text(busy ? 'Checking...' : 'Remove item'),
        ),
      ],
    );
  }
}

class TicketBody extends StatelessWidget {
  const TicketBody({super.key, required this.sale, this.actionLabel = 'Close'});

  final Sale sale;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            sale.saleType,
            sale.paymentMethod,
            if (sale.gcashTxnNo.isNotEmpty) sale.gcashTxnNo,
            formatDate(sale.createdAt),
          ].join(' · '),
          style: const TextStyle(color: JaColors.muted),
        ),
        const SizedBox(height: 4),
        Text('Cashier: ${sale.cashier?.name ?? '—'}', style: const TextStyle(color: JaColors.muted, fontSize: 13)),
        const SizedBox(height: 16),
        ...sale.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.qty} × ${item.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${item.sku} · ${peso(item.unitPrice)}', style: const TextStyle(color: JaColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Text(peso(item.lineTotal), style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
        const Divider(color: JaColors.line),
        _totalRow('Subtotal', peso(sale.subtotal)),
        _totalRow('Discount', peso(sale.discount)),
        _totalRow('Total', peso(sale.total), bold: true),
        _totalRow('Paid', peso(sale.amountPaid)),
        if (sale.paymentMethod.toLowerCase() == 'gcash')
          _totalRow('GCash Txn No.', sale.gcashTxnNo.isEmpty ? '—' : sale.gcashTxnNo),
        _totalRow('Change', peso(sale.change)),
        const SizedBox(height: 16),
        JaButton(
          label: 'Print',
          icon: Icons.print,
          expanded: true,
          onPressed: () async {
            try {
              await printSaleReceipt(sale);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to print receipt.')),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        JaButton(
          label: actionLabel,
          primary: true,
          expanded: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 18 : 14)),
        ],
      ),
    );
  }
}

void showTicket(BuildContext context, Sale sale) {
  showJaDialog(
    context: context,
    title: 'Ticket ${sale.invoiceNo}',
    child: TicketBody(sale: sale),
  );
}

class JaTable extends StatelessWidget {
  const JaTable({super.key, required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 340),
        child: DataTable(
          headingTextStyle: const TextStyle(color: JaColors.muted, fontWeight: FontWeight.w600),
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }
}
