class TransactionCategories {
  static const List<String> income = [
    'Зарплата',
    'Подарунки',
    'Підробіток',
    'Інше',
  ];

  static const List<String> expense = [
    'Продукти',
    'Транспорт',
    'Покупки',
    'Розваги',
    'Комунальні послуги',
    'Інше',
  ];

  static List<String> forType(bool isIncome) {
    return isIncome ? income : expense;
  }
}
