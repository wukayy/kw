import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'main.dart';
import 'transaction_categories.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, Object?>> transactions = [];
  String filter = 'Усі';
  String selectedCategory = 'Усі категорії';
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      final rows = await DatabaseHelper.instance.getTransactions();

      if (!mounted) return;

      setState(() {
        transactions = rows;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Помилка завантаження: $error')));
    }
  }

  List<Map<String, Object?>> get filteredTransactions {
    return transactions.where((transaction) {
      final isIncome = (transaction['is_income'] as int) == 1;

      final title = (transaction['title'] as String).toLowerCase();

      final description = ((transaction['description'] as String?) ?? '')
          .toLowerCase();

      final category = (transaction['category'] as String?) ?? 'Інше';

      final query = searchQuery.toLowerCase().trim();

      final matchesFilter =
          filter == 'Усі' ||
          (filter == 'Доходи' && isIncome) ||
          (filter == 'Витрати' && !isIncome);

      final matchesCategory =
          selectedCategory == 'Усі категорії' || category == selectedCategory;

      final matchesSearch =
          title.contains(query) ||
          description.contains(query) ||
          category.toLowerCase().contains(query);

      return matchesFilter && matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> editTransaction(Map<String, Object?> row) async {
    final transaction = FinanceTransaction.fromMap(row);

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

  Future<void> deleteTransaction(int id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити операцію?'),
        content: Text('Операцію "$title" буде видалено.'),
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
      await DatabaseHelper.instance.deleteTransaction(id);
      await loadTransactions();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка видалення: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleTransactions = filteredTransactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Історія операцій'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Пошук операцій',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Усі', label: Text('Усі')),
                      ButtonSegment(value: 'Доходи', label: Text('Доходи')),
                      ButtonSegment(value: 'Витрати', label: Text('Витрати')),
                    ],
                    selected: {filter},
                    onSelectionChanged: (selection) {
                      setState(() {
                        filter = selection.first;
                        selectedCategory = 'Усі категорії';
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  key: ValueKey(filter),
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Фільтр за категорією',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items:
                      [
                        'Усі категорії',
                        ...{
                          if (filter != 'Витрати')
                            ...TransactionCategories.income,
                          if (filter != 'Доходи')
                            ...TransactionCategories.expense,
                        },
                      ].map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : visibleTransactions.isEmpty
                ? const Center(child: Text('Операцій не знайдено'))
                : ListView.builder(
                    itemCount: visibleTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = visibleTransactions[index];

                      final id = transaction['id'] as int;
                      final title = transaction['title'] as String;
                      final category =
                          (transaction['category'] as String?) ?? 'Інше';
                      final amount = (transaction['amount'] as num).toDouble();
                      final isIncome = (transaction['is_income'] as int) == 1;
                      final date = DateTime.parse(
                        transaction['date'] as String,
                      );

                      final formattedDate =
                          '${date.day.toString().padLeft(2, '0')}.'
                          '${date.month.toString().padLeft(2, '0')}.'
                          '${date.year}';

                      return ListTile(
                        leading: Icon(
                          isIncome
                              ? Icons.account_balance_wallet
                              : Icons.shopping_cart,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                        title: Text(title),
                        subtitle: Text('$category • $formattedDate'),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}'
                          '${amount.toStringAsFixed(2)} ₴',
                          style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => editTransaction(transaction),
                        onLongPress: () => deleteTransaction(id, title),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
