const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _fullMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatCurrency(double amount, {bool signed = false}) {
  final prefix = signed && amount > 0 ? '+' : '';
  final absolute = amount.abs();
  final decimals = absolute == absolute.roundToDouble() ? 0 : 2;
  final value = absolute.toStringAsFixed(decimals);
  final sign = amount < 0 ? '-' : prefix;
  return '$sign₹$value';
}

String formatShortDate(DateTime date) {
  return '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
}

String formatMonthYear(DateTime date) {
  return '${_fullMonthNames[date.month - 1]} ${date.year}';
}

String formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

bool isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
