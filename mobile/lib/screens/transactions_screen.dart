import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../layout.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';
import '../widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Sale> sales = [];
  String query = '';
  String error = '';
  int page = 1;
  int pages = 1;
  int total = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({int? nextPage}) async {
    try {
      final result = await context.read<ApiClient>().sales(page: nextPage ?? page, limit: 25);
      if (!mounted) return;
      setState(() {
        sales = result.items;
        page = result.page;
        pages = result.pages;
        total = result.total;
        error = '';
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load transactions.');
    }
  }

  List<Sale> get filtered {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return sales;
    return sales.where((sale) {
      return [sale.invoiceNo, sale.saleType, sale.paymentMethod, sale.cashier?.name ?? '']
          .join(' ')
          .toLowerCase()
          .contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) const PageHeader(eyebrow: 'Sales history', title: 'Transactions'),
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        TextField(
          decoration: InputDecoration(hintText: 'Search invoice, type, payment, or cashier', isDense: compact),
          onChanged: (value) => setState(() => query = value),
        ),
        SizedBox(height: compact ? 8 : 16),
        Expanded(
          child: JaPanel(
            padding: EdgeInsets.all(compact ? 10 : 18),
            child: SingleChildScrollView(
              child: JaTable(
                columns: const [
                  DataColumn(label: Text('Invoice')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Payment')),
                  DataColumn(label: Text('Cashier')),
                  DataColumn(label: Text('When')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('')),
                ],
                rows: filtered.isEmpty
                    ? const [
                        DataRow(
                          cells: [
                            DataCell(Text('No transactions yet.')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                            DataCell(Text('')),
                          ],
                        ),
                      ]
                    : filtered
                        .map(
                          (sale) => DataRow(
                            cells: [
                              DataCell(Text(sale.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700))),
                              DataCell(Text(sale.saleType)),
                              DataCell(Text(sale.paymentMethod)),
                              DataCell(Text(sale.cashier?.name ?? '—')),
                              DataCell(Text(formatDate(sale.createdAt))),
                              DataCell(Text(peso(sale.total))),
                              DataCell(
                                TextButton(
                                  onPressed: () => showTicket(context, sale),
                                  child: const Text('View'),
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
        if (pages > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: page <= 1 ? null : () => load(nextPage: page - 1),
                child: const Text('Previous'),
              ),
              Expanded(
                child: Text(
                  'Page $page of $pages · $total total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: JaColors.muted, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: page >= pages ? null : () => load(nextPage: page + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
