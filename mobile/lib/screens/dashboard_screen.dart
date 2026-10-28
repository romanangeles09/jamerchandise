import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../models.dart';
import '../money.dart';
import '../theme.dart';
import '../widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? data;
  int year = manilaYear();
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
      final next = await context.read<ApiClient>().dashboard(year: year);
      if (!mounted) return;
      setState(() {
        data = next;
        year = next.year == 0 ? year : next.year;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load dashboard.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openMonth(MonthPoint month) async {
    try {
      final detail = await context.read<ApiClient>().dashboardMonth(year: year, month: month.month);
      if (!mounted) return;
      await showJaDialog(
        context: context,
        title: '${detail.label} ${detail.year}',
        width: 860,
        child: _MonthDetailView(detail: detail),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() => error = err is ApiException ? err.message : 'Unable to load month details.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = data?.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(eyebrow: 'Today at the counter', title: 'Dashboard'),
        if (error.isNotEmpty) ...[JaAlert(error), const SizedBox(height: 12)],
        Expanded(
          child: loading && data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: Icons.account_balance_wallet_outlined,
                            label: "Today's sales",
                            value: peso(today?.revenue),
                            hint: '${today?.sales ?? 0} ${(today?.sales ?? 0) == 1 ? 'ticket' : 'tickets'}',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            icon: Icons.storefront_outlined,
                            label: 'Retail',
                            value: peso(today?.retail),
                            hint: 'Walk-in counter',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Wholesale',
                            value: peso(today?.wholesale),
                            hint: 'Bulk orders',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            icon: Icons.inventory_2_outlined,
                            label: 'Catalog',
                            value: '${data?.productCount ?? 0}',
                            hint: '${data?.categoryCount ?? 0} categories',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 12,
                          child: JaPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Last 7 days', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                SizedBox(height: 220, child: WeeklyChart(weekly: data?.weekly ?? const [])),
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
                                Text('Low stock', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                if ((data?.lowStock ?? const []).isEmpty)
                                  const Text('Stock levels look healthy.', style: TextStyle(color: JaColors.muted))
                                else
                                  ...data!.lowStock.map(
                                    (product) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                Text(product.category?.name ?? '', style: const TextStyle(color: JaColors.muted, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          Text('${product.stock} ${product.unit}', style: const TextStyle(color: JaColors.warn, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    JaPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('Monthly sales', style: Theme.of(context).textTheme.titleLarge)),
                              SizedBox(
                                width: 140,
                                child: FieldLabel(
                                  label: 'Year',
                                  child: DropdownButtonFormField<int>(
                                    initialValue: year,
                                    items: (data?.years.isNotEmpty == true ? data!.years : [year])
                                        .map((item) => DropdownMenuItem(value: item, child: Text('$item')))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => year = value);
                                      load();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 250,
                            child: MonthlyChart(
                              monthly: data?.monthly ?? const [],
                              year: year,
                              onSelect: openMonth,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    JaPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent tickets', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          JaTable(
                            columns: const [
                              DataColumn(label: Text('Invoice')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Cashier')),
                              DataColumn(label: Text('When')),
                              DataColumn(label: Text('Total')),
                            ],
                            rows: (data?.recentSales ?? const []).isEmpty
                                ? [
                                    const DataRow(
                                      cells: [
                                        DataCell(Text('No sales yet. Open POS to start.')),
                                        DataCell(Text('')),
                                        DataCell(Text('')),
                                        DataCell(Text('')),
                                        DataCell(Text('')),
                                      ],
                                    ),
                                  ]
                                : data!.recentSales
                                      .map(
                                        (sale) => DataRow(
                                          cells: [
                                            DataCell(Text(sale.invoiceNo)),
                                            DataCell(Text(sale.saleType)),
                                            DataCell(Text(sale.cashier?.name ?? '')),
                                            DataCell(Text(formatDate(sale.createdAt))),
                                            DataCell(Text(peso(sale.total))),
                                          ],
                                        ),
                                      )
                                      .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.weekly});

  final List<DayPoint> weekly;

  @override
  Widget build(BuildContext context) {
    if (weekly.isEmpty) return const Text('No sales data yet.', style: TextStyle(color: JaColors.muted));
    final maxValue = niceCeil(weekly.fold<double>(0, (sum, day) => day.revenue > sum ? day.revenue : sum));
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [1, 0.75, 0.5, 0.25, 0]
                .map(
                  (ratio) => Text(
                    axisLabel(maxValue * ratio),
                    style: const TextStyle(color: JaColors.muted, fontSize: 11),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _LinePainter(weekly.map((day) => day.revenue).toList(), maxValue),
                  child: const SizedBox.expand(),
                ),
              ),
              Row(
                children: weekly
                    .map(
                      (day) => Expanded(
                        child: Text(
                          weekdayShort(day.date),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: JaColors.muted, fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MonthlyChart extends StatelessWidget {
  const MonthlyChart({super.key, required this.monthly, required this.year, required this.onSelect});

  final List<MonthPoint> monthly;
  final int year;
  final ValueChanged<MonthPoint> onSelect;

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) return const Text('No monthly sales yet.', style: TextStyle(color: JaColors.muted));
    final maxValue = niceCeil(monthly.fold<double>(0, (sum, month) => month.revenue > sum ? month.revenue : sum));
    final current = year == manilaYear() ? manilaMonth() : 0;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [1, 0.75, 0.5, 0.25, 0]
                .map(
                  (ratio) => Text(
                    axisLabel(maxValue * ratio),
                    style: const TextStyle(color: JaColors.muted, fontSize: 11),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slot = constraints.maxWidth / monthly.length;
                    return Stack(
                      children: [
                        CustomPaint(
                          painter: _BarPainter(
                            monthly.map((month) => month.revenue).toList(),
                            maxValue,
                            currentIndex: monthly.indexWhere((month) => month.month == current),
                          ),
                          child: const SizedBox.expand(),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < monthly.length; i++)
                              SizedBox(
                                width: slot,
                                height: constraints.maxHeight,
                                child: GestureDetector(onTap: () => onSelect(monthly[i]), behavior: HitTestBehavior.opaque),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: monthly
                    .map(
                      (month) => Expanded(
                        child: TextButton(
                          onPressed: () => onSelect(month),
                          child: Text(month.label, style: const TextStyle(color: JaColors.muted, fontSize: 12)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.maxValue);

  final List<double> values;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE4D9C6)
      ..strokeWidth = 1;
    for (final ratio in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = size.height * (1 - ratio);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(((i + 0.5) / values.length) * size.width, size.height - (values[i] / maxValue) * size.height),
    ];
    final area = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      area.lineTo(point.dx, point.dy);
      line.lineTo(point.dx, point.dy);
    }
    area
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = const Color(0x291F6A4F));
    canvas.drawPath(
      line,
      Paint()
        ..color = JaColors.forest
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = JaColors.copper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in points) {
      canvas.drawCircle(point, 4.5, fill);
      canvas.drawCircle(point, 4.5, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxValue != maxValue;
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.values, this.maxValue, {required this.currentIndex});

  final List<double> values;
  final double maxValue;
  final int currentIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE4D9C6)
      ..strokeWidth = 1;
    for (final ratio in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = size.height * (1 - ratio);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;
    final slot = size.width / values.length;
    final barWidth = slot * 0.55;
    for (var i = 0; i < values.length; i++) {
      final height = (values[i] / maxValue) * size.height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(slot * i + (slot - barWidth) / 2, size.height - height, barWidth, height < 2 && values[i] > 0 ? 2 : height),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = i == currentIndex ? JaColors.copper : JaColors.forest,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxValue != maxValue || oldDelegate.currentIndex != currentIndex;
}

class _MonthDetailView extends StatelessWidget {
  const _MonthDetailView({required this.detail});

  final MonthDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _mini('Total', peso(summary.total)),
            _mini('Tickets', '${summary.tickets}'),
            _mini('Items', '${summary.itemCount}'),
            _mini('Discount', peso(summary.discount)),
            _mini('Cash', peso(summary.cash)),
            _mini('GCash', peso(summary.gcash)),
            _mini('Retail', peso(summary.retail)),
            _mini('Wholesale', peso(summary.wholesale)),
          ],
        ),
        if (detail.cashiers.length > 1) ...[
          const SizedBox(height: 16),
          Text('By cashier', style: Theme.of(context).textTheme.titleMedium),
          JaTable(
            columns: const [
              DataColumn(label: Text('Cashier')),
              DataColumn(label: Text('Tickets')),
              DataColumn(label: Text('Amount')),
            ],
            rows: detail.cashiers
                .map(
                  (row) => DataRow(
                    cells: [
                      DataCell(Text(row.name)),
                      DataCell(Text('${row.tickets}')),
                      DataCell(Text(peso(row.total))),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        Text('Products sold', style: Theme.of(context).textTheme.titleMedium),
        JaTable(
          columns: const [
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Qty')),
            DataColumn(label: Text('Amount')),
          ],
          rows: detail.products.isEmpty
              ? const [
                  DataRow(
                    cells: [
                      DataCell(Text('No product sales this month.')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                    ],
                  ),
                ]
              : detail.products
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
        const SizedBox(height: 16),
        Text('Tickets', style: Theme.of(context).textTheme.titleMedium),
        JaTable(
          columns: const [
            DataColumn(label: Text('Invoice')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Payment')),
            DataColumn(label: Text('Cashier')),
            DataColumn(label: Text('When')),
            DataColumn(label: Text('Total')),
          ],
          rows: detail.sales.isEmpty
              ? const [
                  DataRow(
                    cells: [
                      DataCell(Text('No tickets this month.')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                    ],
                  ),
                ]
              : detail.sales
                    .map(
                      (sale) => DataRow(
                        cells: [
                          DataCell(
                            TextButton(
                              onPressed: () => showTicket(context, sale),
                              child: Text(sale.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          DataCell(Text(sale.saleType)),
                          DataCell(Text(sale.paymentMethod)),
                          DataCell(Text(sale.cashier?.name ?? '')),
                          DataCell(Text(formatDate(sale.createdAt))),
                          DataCell(Text(peso(sale.total))),
                        ],
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }

  Widget _mini(String label, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JaColors.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: JaColors.muted, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
