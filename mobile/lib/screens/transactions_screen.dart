import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../money.dart';
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

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final next = await context.read<ApiClient>().sales(limit: 100);
      if (!mounted) return;
      setState(() => sales = next);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(eyebrow: 'Sales history', title: 'Transactions'),
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        TextField(
          decoration: const InputDecoration(hintText: 'Search invoice, type, payment, or cashier'),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: JaPanel(
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
                                DataCell(Text(sale.cashier?.name ?? '')),
                                DataCell(Text(formatDate(sale.createdAt))),
                                DataCell(Text(peso(sale.total))),
                                DataCell(
                                  TextButton(onPressed: () => showTicket(context, sale), child: const Text('View')),
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
