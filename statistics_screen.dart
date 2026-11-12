import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, double> expensesByCategory = {};
  bool isLoading = true;
  double totalIncome = 0;
  DateTime selectedMonth = DateTime.now();

  final List<Color> chartColors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    loadStatistics();
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
      );
      isLoading = true;
    });

    loadStatistics();
  }

  String get monthTitle {
    const months = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень',
    ];

    return '${months[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  Future<void> loadStatistics() async {
    try {
      final transactions = await DatabaseHelper.instance.getTransactions();

      final Map<String, double> totals = {};
      double income = 0;

      for (final transaction in transactions) {
        final isIncome = (transaction['is_income'] as int) == 1;

        final date = DateTime.parse(transaction['date'] as String);

        if (date.year != selectedMonth.year ||
            date.month != selectedMonth.month) {
          continue;
        }

        if (isIncome) {
          income += (transaction['amount'] as num).toDouble();
          continue;
        }

        final category = (transaction['category'] as String?) ?? 'Інше';

        final amount = (transaction['amount'] as num).toDouble();

        totals[category] = (totals[category] ?? 0) + amount;
      }

      if (!mounted) return;

      setState(() {
        expensesByCategory = totals;
        totalIncome = income;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка статистики: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = expensesByCategory.entries.toList();

    final totalExpenses = expensesByCategory.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );

    final balance = totalIncome - totalExpenses;

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика витрат'), centerTitle: true),

      bottomNavigationBar: null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => changeMonth(-1),
                      ),
                      Text(
                        monthTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => changeMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Загальні витрати'),
                          const SizedBox(height: 8),
                          Text(
                            '${totalExpenses.toStringAsFixed(2)} ₴',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text('Доходи'),
                                const SizedBox(height: 8),
                                Text(
                                  '${totalIncome.toStringAsFixed(2)} ₴',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text('Баланс'),
                                const SizedBox(height: 8),
                                Text(
                                  '${balance.toStringAsFixed(2)} ₴',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: balance >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 24),

                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('За цей місяць витрат немає')),
                    ),

                  if (entries.isNotEmpty)
                    SizedBox(
                      height: 260,
                      child: PieChart(
                        PieChartData(
                          sections: List.generate(entries.length, (index) {
                            final entry = entries[index];
                            final percentage =
                                entry.value / totalExpenses * 100;

                            return PieChartSectionData(
                              color: chartColors[index % chartColors.length],
                              value: entry.value,
                              title: '${percentage.toStringAsFixed(0)}%',
                              radius: 100,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }),
                          sectionsSpace: 3,
                          centerSpaceRadius: 35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Порівняння доходів і витрат',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 230,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            [
                                  totalIncome,
                                  totalExpenses,
                                ].reduce((a, b) => a > b ? a : b) *
                                1.2 +
                            1,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() == 0) {
                                  return const Text('Доходи');
                                }
                                if (value.toInt() == 1) {
                                  return const Text('Витрати');
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: totalIncome,
                                color: Colors.green,
                                width: 45,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: totalExpenses,
                                color: Colors.red,
                                width: 45,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 28),
                  const Text(
                    'Витрати за категоріями',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(entries.length, (index) {
                    final entry = entries[index];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            chartColors[index % chartColors.length],
                        radius: 10,
                      ),
                      title: Text(entry.key),
                      trailing: Text(
                        '${entry.value.toStringAsFixed(2)} ₴',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
