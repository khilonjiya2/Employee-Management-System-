import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Translates raw exception text (often a raw Postgres/Supabase error)
/// into something a user can actually understand. Centralized here so
/// every screen's catch block can use the same logic instead of showing
/// "PostgrestException(message: ..., code: 23505, ...)" to users.
class ErrorUtils {
  ErrorUtils._();

  static String friendly(Object e) {
    final raw = e.toString();

    if (raw.contains('already registered to another account')) {
      return 'This UPI ID is already registered to another account. Please use a different one.';
    }
    if (raw.contains('mobile number is already registered')) {
      return 'This mobile number is already used by another account. Each mobile number must be unique.';
    }
    if (raw.contains('Login already exists for this employee code')) {
      return 'A login already exists for this employee.';
    }
    if (raw.toLowerCase().contains('duplicate key') &&
        raw.contains('upi_id')) {
      return 'This UPI ID is already in use. Please use a different one.';
    }
    if (raw.toLowerCase().contains('duplicate key') &&
        (raw.contains('email') || raw.contains('employee_code') || raw.contains('supervisor_code'))) {
      return 'This username/code is already taken. Please choose another.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network and try again.';
    }

    return raw
        .replaceAll('PostgrestException(message: ', '')
        .replaceAll('AuthException: ', '')
        .replaceAll('Exception: ', '')
        .split(', code:')
        .first
        .trim();
  }
}

class DateUtils {
  DateUtils._();

  static String formatDate(DateTime date) =>
      DateFormat(AppConstants.dateFormat).format(date);

  // Fix: timestamps from Supabase (timestamptz columns) parse as UTC.
  // Formatting a UTC DateTime directly displays UTC time, not the
  // user's local time \u{2014} this was the cause of "submitted"/"reviewed"
  // times looking wrong. .toLocal() converts to the device's local
  // timezone before formatting, exactly once, here, so every call site
  // using this shared helper is automatically correct.
  static String formatDateTime(DateTime date) =>
      DateFormat(AppConstants.dateTimeFormat).format(date.toLocal());

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
    symbol: '\u{20B9}',
    decimalDigits: 2,
  );

  static String format(num amount) => _formatter.format(amount);

  static String formatCompact(num amount) {
    if (amount >= 100000) {
      return '\u{20B9}${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '\u{20B9}${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u{20B9}${amount.toStringAsFixed(0)}';
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

/// Retries [action] a few times with a short, increasing delay before
/// giving up. Used for dashboard/profile-linked data fetches that can
/// transiently race a just-completed login or logout — the row genuinely
/// exists, but a fresh RLS/JWT context or a brand-new account's linked row
/// (created by an edge function a beat after the profile itself) hasn't
/// fully propagated yet. This is what makes the dashboard load correctly
/// the first time after logging in — including immediately after logging
/// out and back in as a different user — without ever needing a manual
/// reload: any transient hiccup resolves itself within about a second and
/// a half instead of surfacing as an error or requiring the person to tap
/// anything.
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int attempts = 4,
  Duration initialDelay = const Duration(milliseconds: 250),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      return await action();
    } catch (_) {
      if (attempt == attempts - 1) rethrow;
      await Future.delayed(initialDelay * (attempt + 1));
    }
  }
  // Unreachable — the loop above always either returns or rethrows on the
  // final attempt — but Dart's analyzer needs an explicit exit path.
  return action();
}
