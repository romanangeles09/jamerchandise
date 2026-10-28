import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';
import '../widgets.dart';

class CutoffScreen extends StatefulWidget {
  const CutoffScreen({super.key});

  @override
  State<CutoffScreen> createState() => _CutoffScreenState();
}

class _CutoffScreenState extends State<CutoffScreen> {
  String date = manilaToday();
  String payment = 'all';
  String cashier = 'all';
  CutoffReport? data;
  String error = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final next = await context.read<ApiClient>().cutoff(date: date, payment: payment, cashier: cashier);
      if (!mounted) return;
      setState(() => data = next);
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load cutoff.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickDate() async {
    final parsed = DateTime.tryParse(date) ?? DateTime.now();
    final next = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (next == null) return;
    setState(() => date = DateTime(next.year, next.month, next.day).toIso8601String().split('T').first);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = data?.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          eyebrow: 'Shift report',
          title: 'Cutoff',
          trailing: Text(peso(summary?.total), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: JaColors.forest)),
        ),
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        if (loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Loading cutoff...', style: TextStyle(color: JaColors.muted))),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 200,
              child: FieldLabel(
                label: 'Day',
                child: InkWell(
                  onTap: pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Text(date),
                  ),
                ),
              ),
            ),
            if (data?.canPickCashier == true)
              SizedBox(
                width: 220,
                child: FieldLabel(
                  label: 'Cashier',
                  child: DropdownButtonFormField<String>(
                    initialValue: cashier,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All cashiers')),
                      ...?data?.cashiers.map((user) => DropdownMenuItem(value: user.id, child: Text(user.name))),
                    ],
                    onChanged: (value) {
                      setState(() => cashier = value ?? 'all');
                      load();
                    },
                  ),
                ),
              ),
            FieldLabel(
              label: 'Payment',
              child: SegmentedChoice(
                value: payment,
                options: const [('all', 'All'), ('cash', 'Cash'), ('gcash', 'GCash')],
                onChanged: (value) {
                  setState(() => payment = value);
                  load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.receipt_long_outlined,
                label: 'Tickets',
                value: '${summary?.tickets ?? 0}',
                hint: '${summary?.itemCount ?? 0} items sold',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Items sold',
                value: '${summary?.itemCount ?? 0}',
                hint: '${peso(summary?.subtotal)} before discount',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Cash',
                value: peso(summary?.cash),
                hint: 'Cash payments',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                icon: Icons.payments_outlined,
                label: 'GCash',
                value: peso(summary?.gcash),
                hint: 'GCash payments',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 12,
                child: JaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Products sold', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: JaTable(
                            columns: const [
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('SKU')),
                              DataColumn(label: Text('Qty')),
                              DataColumn(label: Text('Amount')),
                            ],
                            rows: (data?.products ?? const []).isEmpty
                                ? const [
                                    DataRow(
                                      cells: [
                                        DataCell(Text('No product sales for this cutoff.')),
                                        DataCell(Text('')),
                                        DataCell(Text('')),
                                        DataCell(Text('')),
                                      ],
                                    ),
                                  ]
                                : data!.products
                                      .map(
                                        (product) => DataRow(
                                          cells: [
                                            DataCell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                            DataCell(Text(product.sku)),
                                            DataCell(Text('${product.qty}')),
                                            DataCell(Text(peso(product.amount))),
                                          ],
                                        ),
                                      )
                                      .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 8,
                child: JaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tickets', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Expanded(
                        child: (data?.sales ?? const []).isEmpty
                            ? const Text('No tickets for this cutoff.', style: TextStyle(color: JaColors.muted))
                            : ListView.builder(
                                itemCount: data!.sales.length,
                                itemBuilder: (context, index) {
                                  final sale = data!.sales[index];
                                  return Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(sale.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                        '${sale.cashier?.name ?? '—'} · ${sale.paymentMethod} · ${formatDate(sale.createdAt)}',
                                      ),
                                      trailing: Text(peso(sale.total)),
                                      onTap: () => showTicket(context, sale),
                                    ),
                                  );
                                },
                              ),
                      ),
                      if ((summary?.discount ?? 0) > 0)
                        Text('Discounts: ${peso(summary?.discount)}', style: const TextStyle(color: JaColors.muted)),
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
