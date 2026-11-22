import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../i18n/app_country.dart';
import '../i18n/i18n.dart';

Future<void> initFormatters() async {
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  Intl.defaultLocale = I18n.language.name;
}

String get _locale => I18n.language.name;

final NumberFormat _money = NumberFormat('#,##0', 'en');

DateFormat get _date => DateFormat('d MMM yyyy', _locale);
DateFormat get _dateLong =>
    DateFormat(I18n.isEnglish ? 'EEEE, d MMMM yyyy' : 'EEEE، d MMMM yyyy', _locale);
DateFormat get _time => DateFormat('h:mm a', _locale);
DateFormat get _month => DateFormat('MMMM yyyy', _locale);

/// Country used when a screen does not know the compound's country explicitly.
/// Updated from the signed-in profile so managers/tenants see local currency.
AppCountry defaultDisplayCountry = AppCountry.iq;

String formatMoney(
  num amount, {
  bool withCurrency = false,
  bool compact = false,
  AppCountry? country,
}) {
  final value = amount.toDouble();
  final resolved = country ?? defaultDisplayCountry;
  final symbol = resolved.currencySymbol(english: I18n.isEnglish);
  String withSymbol(String number) {
    if (!withCurrency) return number;
    return symbol == '\$' ? '\$$number' : '$number $symbol';
  }

  if (compact) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      final text = millions == millions.roundToDouble()
          ? millions.toStringAsFixed(0)
          : millions.toStringAsFixed(1);
      return withSymbol(
          I18n.isEnglish ? '${text}M' : '$text ${I18n.isEnglish ? 'M' : 'مليون'}');
    }
    if (value >= 1000) {
      final thousands = value / 1000;
      final text = thousands == thousands.roundToDouble()
          ? thousands.toStringAsFixed(0)
          : thousands.toStringAsFixed(0);
      return withSymbol(
          I18n.isEnglish ? '${text}K' : '$text ${I18n.isEnglish ? 'K' : 'ألف'}');
    }
  }
  final formatted = _money.format(value);
  return withSymbol(formatted);
}

String formatDate(DateTime? date) => date == null ? '—' : _date.format(date);
String formatDateLong(DateTime? date) => date == null ? '—' : _dateLong.format(date);
String formatTime(DateTime? date) => date == null ? '' : _time.format(date);
String formatMonth(DateTime date) => _month.format(date);
// Postgres expects ASCII digits; DateFormat would inherit the Arabic locale
// and emit ٢٠٢٦-١١-٠١, which fails with 22P02.
String isoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String formatRelative(DateTime? date) {
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (I18n.isEnglish) {
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} d ago';
    return formatDate(date);
  }
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
  return formatDate(date);
}

String formatDaysLeft(int days) {
  if (I18n.isEnglish) {
    if (days < 0) return '${-days} days overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }
  if (days < 0) return 'متأخر ${-days} يوم';
  if (days == 0) return 'يستحق اليوم';
  if (days == 1) return 'باقي يوم واحد';
  if (days == 2) return 'باقي يومان';
  if (days <= 10) return 'باقي $days أيام';
  return 'باقي $days يوماً';
}

String leaseDurationLabel(int months) {
  if (I18n.isEnglish) {
    return switch (months) {
      1 => '1 month',
      12 => '1 year',
      _ => '$months months',
    };
  }
  return switch (months) {
    1 => 'شهر',
    3 => '3 أشهر',
    6 => '6 أشهر',
    12 => 'سنة',
    _ => '$months شهر',
  };
}

/// Adds calendar months while keeping the day inside the target month
/// (31 Jan + 1 month = 28/29 Feb instead of overflowing into March).
DateTime addMonthsClamped(DateTime date, int months) {
  final zeroBased = date.month - 1 + months;
  final targetYear = date.year + zeroBased ~/ 12;
  final targetMonth = zeroBased % 12 + 1;
  final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(targetYear, targetMonth, day);
}

String greeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (I18n.isEnglish) {
    return hour < 12 ? 'Good morning' : 'Good evening';
  }
  if (hour < 12) return 'صباح الخير';
  if (hour < 17) return 'مساء الخير';
  return 'مساء الخير';
}

// ------------------------------------------------------------------ phones

String normalizeLocalPhone(String input) => AppCountry.iq.normalizePhone(input);

String toE164Iraq(String input) => AppCountry.iq.toE164(input);

bool isValidIraqiPhone(String input) => AppCountry.iq.isValidPhone(input);

String toE164(String input, AppCountry country) => country.toE164(input);

bool isValidPhone(String input, AppCountry country) =>
    country.isValidPhone(input);

String prettyPhone(String? phone) =>
    AppCountry.fromPhone(phone).prettyPhone(phone);

// ------------------------------------------------------------------ misc

String truncate(String text, int max) {
  final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return clean.length <= max ? clean : '${clean.substring(0, max)}…';
}

String percent(num value) => '${(value * 100).round()}%';
