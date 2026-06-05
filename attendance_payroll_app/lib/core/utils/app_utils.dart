import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class DateUtils {
  DateUtils._();

  static String formatDate(DateTime date) =>
      DateFormat(AppConstants.dateFormat).format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat(AppConstants.dateTimeFormat).format(date);

  static String formatMonthYear(DateTime date) =>
      DateFormat(AppConstants.monthYearFormat).format(date);

  static String formatApiDate(DateTime date) =>
      DateFormat(AppConstants.apiDateFormat).format(date);

  static DateTime parseDate(String date) =>
      DateFormat(AppConstants.apiDateFormat).parse(date);

  static String getMonthName(int month) =>
      DateFormat('MMMM').format(DateTime(2024, month));

  static List<DateTime> getDaysInMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    return List.generate(
      lastDay.day,
      (i) => DateTime(year, month, i + 1),
    );
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());
}

class CurrencyUtils {
  CurrencyUtils._();

  static final _formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(num amount) => _formatter.format(amount);

  static String formatCompact(num amount) {
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }
}

class StringUtils {
  StringUtils._();

  static String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String titleCase(String s) =>
      s.split(' ').map(capitalize).join(' ');

  static bool isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  static bool isValidMobile(String mobile) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(mobile);

  static bool isValidAadhaar(String aadhaar) =>
      RegExp(r'^\d{12}$').hasMatch(aadhaar.replaceAll(' ', ''));

  static String maskAadhaar(String aadhaar) {
    if (aadhaar.length < 4) return aadhaar;
    return '****-****-${aadhaar.substring(aadhaar.length - 4)}';
  }
}

class ValidationUtils {
  ValidationUtils._();

  static String? validateRequired(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!StringUtils.isValidEmail(value)) return 'Enter a valid email';
    return null;
  }

  static String? validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!StringUtils.isValidMobile(value)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }
}
