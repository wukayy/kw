import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'history_screen.dart';
import 'transaction_categories.dart';
import 'statistics_screen.dart';

void main() {
  runApp(const PersonalFinanceApp());
}

class FinanceTransaction {
  final int? id;
  final String title;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final String category;
  final String description;

  FinanceTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.date,
    this.category = 'Інше',
    this.description = '',
  });

  factory FinanceTransaction.fromMap(Map<String, Object?> map) {
    return FinanceTransaction(
      id: map['id'] as int,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      isIncome: (map['is_income'] as int) == 1,
      date: DateTime.parse(map['date'] as String),
      category: (map['category'] as String?) ?? 'Інше',
      description: (map['description'] as String?) ?? '',
    );
  }
}

class PersonalFinanceApp extends StatelessWidget {
  const PersonalFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Personal Finance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int selectedIndex = 0;
  int historyVersion = 0;
  int statisticsVersion = 0;
  int homeVersion = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeScreen(key: ValueKey('home_$homeVersion')),
          HistoryScreen(key: ValueKey('history_$historyVersion')),
          StatisticsScreen(key: ValueKey('statistics_$statisticsVersion')),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,

        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;

            if (index == 0) {
              homeVersion++;
            } else if (index == 1) {
              historyVersion++;
            } else if (index == 2) {
              statisticsVersion++;
            }
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Головна',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Історія',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Статистика',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<FinanceTransaction> transactions = [];

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> openStatistics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StatisticsScreen()),
    );
  }

  Future<void> loadTransactions() async {
    try {
      final rows = await DatabaseHelper.instance.getTransactions();

      if (!mounted) return;

      setState(() {
        transactions
          ..clear()
          ..addAll(rows.map(FinanceTransaction.fromMap));
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Помилка завантаження: $error')));
    }
  }

  double get income => transactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get expenses => transactions
      .where((t) => !t.isIncome)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => income - expenses;

  String formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ₴';
  }

  Future<void> addTransaction(FinanceTransaction transaction) async {
    try {
      await DatabaseHelper.instance.insertTransaction(
        title: transaction.title,
        amount: transaction.amount,
        isIncome: transaction.isIncome,
        date: transaction.date,
        category: transaction.category,
        description: transaction.description,
      );

      await loadTransactions();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка збереження: $error')));
    }
  }

  void openAddTransaction() async {
    final result = await Navigator.push<FinanceTransaction>(
      context,
      MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
    );

    if (result != null) {
      addTransaction(result);
    }
  }

  Future<void> openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );

    if (!mounted) return;
    await loadTransactions();
  }

  Future<void> editTransaction(FinanceTransaction transaction) async {
    final result = await Navigator.push<FinanceTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: transaction),
      ),
    );

    if (result == null || transaction.id == null) return;

    try {
      await DatabaseHelper.instance.updateTransaction(
        id: transaction.id!,
        title: result.title,
        amount: result.amount,
        isIncome: result.isIncome,
        date: result.date,
        category: result.category,
        description: result.description,
      );

      await loadTransactions();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка редагування: $error')));
    }
  }

  Future<void> deleteTransaction(FinanceTransaction transaction) async {
    if (transaction.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити операцію?'),
        content: Text('Операцію "${transaction.title}" буде видалено.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DatabaseHelper.instance.deleteTransaction(transaction.id!);

      await loadTransactions();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка видалення: $error')));
    }
  }

  IconData getCategoryIcon(String category, bool isIncome) {
    switch (category) {
      case 'Продукти':
        return Icons.shopping_basket;
      case 'Транспорт':
        return Icons.directions_bus;
      case 'Покупки':
        return Icons.shopping_bag;
      case 'Розваги':
        return Icons.movie;
      case 'Комунальні послуги':
        return Icons.home;
      case 'Зарплата':
        return Icons.payments;
      case 'Подарунки':
        return Icons.card_giftcard;
      case 'Підробіток':
        return Icons.work;
      default:
        return isIncome ? Icons.account_balance_wallet : Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мої фінанси'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Історія операцій',
            onPressed: openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: 'Статистика',
            onPressed: openStatistics,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Colors.indigo,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Поточний баланс',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatMoney(balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: summaryCard(
                  'Доходи',
                  income,
                  Icons.arrow_downward,
                  Colors.green,
                ),
              ),
              Expanded(
                child: summaryCard(
                  'Витрати',
                  expenses,
                  Icons.arrow_upward,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Останні операції',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: openHistory,
                child: const Text('Усі операції'),
              ),
            ],
          ),

          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('Операцій поки немає')),
            ),
          ...transactions.map(
            (transaction) => ListTile(
              leading: CircleAvatar(
                radius: 23,
                backgroundColor: transaction.isIncome
                    ? Colors.green.withValues(alpha: 0.10)
                    : Colors.red.withValues(alpha: 0.10),
                child: Icon(
                  getCategoryIcon(transaction.category, transaction.isIncome),
                  color: transaction.isIncome ? Colors.green : Colors.red,
                ),
              ),

              title: Text(transaction.title),

              subtitle: Text(
                '${transaction.category} • '
                '${transaction.date.day.toString().padLeft(2, '0')}.'
                '${transaction.date.month.toString().padLeft(2, '0')}.'
                '${transaction.date.year}',
              ),

              trailing: Text(
                '${transaction.isIncome ? '+' : '-'}${formatMoney(transaction.amount)}',
                style: TextStyle(
                  color: transaction.isIncome ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => editTransaction(transaction),
              onLongPress: () => deleteTransaction(transaction),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: openAddTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget summaryCard(String title, double amount, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, color: color),
            Text(title),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoney(amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddTransactionScreen extends StatefulWidget {
  final FinanceTransaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final titleController = TextEditingController();

  bool isIncome = false;

  String selectedCategory = 'Продукти';
  DateTime selectedDate = DateTime.now();
  final descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    if (transaction != null) {
      amountController.text = transaction.amount.toString();
      titleController.text = transaction.title;
      isIncome = transaction.isIncome;
      selectedDate = transaction.date;
      final categories = TransactionCategories.forType(isIncome);
      selectedCategory = categories.contains(transaction.category)
          ? transaction.category
          : 'Інше';
      descriptionController.text = transaction.description;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    titleController.dispose();
    super.dispose();
    descriptionController.dispose();
  }

  void saveTransaction() {
    if (!formKey.currentState!.validate()) return;

    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));

    if (amount == null || !amount.isFinite || amount <= 0) {
      return;
    }

    final transaction = FinanceTransaction(
      title: titleController.text.trim(),
      amount: amount,
      isIncome: isIncome,
      date: selectedDate,
      category: selectedCategory,
      description: descriptionController.text.trim(),
    );

    Navigator.pop(context, transaction);
  }

  Future<void> selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null
              ? 'Додати операцію'
              : 'Редагувати операцію',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Тип операції', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Витрата'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Дохід'),
                  icon: Icon(Icons.add),
                ),
              ],
              selected: {isIncome},
              onSelectionChanged: (selection) {
                setState(() {
                  isIncome = selection.first;
                  selectedCategory = TransactionCategories.forType(isIncome)
                      .first;
                });
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Сума',
                suffixText: '₴',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (amount == null || !amount.isFinite || amount <= 0) {
                  return 'Введіть правильну суму';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Категорія',
                border: OutlineInputBorder(),
              ),
              items: TransactionCategories.forType(isIncome)
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Назва операції',
                hintText: 'Наприклад: Продукти',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введіть назву операції';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),

            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Опис (необов’язково)',
                hintText: 'Додаткова інформація',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Дата операції'),
              subtitle: Text(
                '${selectedDate.day.toString().padLeft(2, '0')}.'
                '${selectedDate.month.toString().padLeft(2, '0')}.'
                '${selectedDate.year}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: selectDate,
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: saveTransaction,
              icon: const Icon(Icons.save),
              label: Text(
                widget.transaction == null
                    ? 'Додати операцію'
                    : 'Зберегти зміни',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
