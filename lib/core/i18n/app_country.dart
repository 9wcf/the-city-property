/// Supported operating countries. Country is a property of a compound and
/// drives the currency, the phone format and the manager scope.
enum AppCountry {
  iq(
    code: 'IQ',
    dialCode: '+964',
    flag: '🇮🇶',
    currencyCode: 'IQD',
    currencyAr: 'د.ع',
    currencyEn: 'IQD',
    nameAr: 'العراق',
    nameEn: 'Iraq',
    phoneHint: '07701234567',
    phoneLength: 11,
  ),
  ae(
    code: 'AE',
    dialCode: '+971',
    flag: '🇦🇪',
    currencyCode: 'AED',
    currencyAr: 'د.إ',
    currencyEn: 'AED',
    nameAr: 'الإمارات',
    nameEn: 'UAE',
    phoneHint: '0501234567',
    phoneLength: 10,
  ),
  us(
    code: 'US',
    dialCode: '+1',
    flag: '🇺🇸',
    currencyCode: 'USD',
    currencyAr: '\$',
    currencyEn: '\$',
    nameAr: 'أمريكا',
    nameEn: 'USA',
    phoneHint: '4155550123',
    phoneLength: 10,
  );

  const AppCountry({
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.currencyCode,
    required this.currencyAr,
    required this.currencyEn,
    required this.nameAr,
    required this.nameEn,
    required this.phoneHint,
    required this.phoneLength,
  });

  final String code;
  final String dialCode;
  final String flag;
  final String currencyCode;
  final String currencyAr;
  final String currencyEn;
  final String nameAr;
  final String nameEn;
  final String phoneHint;
  final int phoneLength;

  static AppCountry fromCode(String? value) {
    final code = (value ?? '').trim().toUpperCase();
    return AppCountry.values.firstWhere(
      (country) => country.code == code,
      orElse: () => AppCountry.iq,
    );
  }

  String currencySymbol({required bool english}) =>
      english ? currencyEn : currencyAr;

  String name({required bool english}) => english ? nameEn : nameAr;

  /// Accepts local or international input and returns the local form used in
  /// profiles: IQ `0770…`, AE `050…`, US `415…`.
  String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    final dial = dialCode.substring(1);
    if (digits.startsWith('+$dial')) {
      digits = digits.substring(dial.length + 1);
    } else if (digits.startsWith(dial) && digits.length > phoneLength) {
      digits = digits.substring(dial.length);
    }
    switch (this) {
      case AppCountry.iq:
        if (digits.length == 10 && digits.startsWith('7')) {
          return '0$digits';
        }
        return digits;
      case AppCountry.ae:
        if (digits.length == 9 && digits.startsWith('5')) {
          return '0$digits';
        }
        return digits;
      case AppCountry.us:
        if (digits.length == 11 && digits.startsWith('1')) {
          return digits.substring(1);
        }
        return digits;
    }
  }

  bool isValidPhone(String input) {
    final local = normalizePhone(input);
    switch (this) {
      case AppCountry.iq:
        return RegExp(r'^07\d{9}$').hasMatch(local);
      case AppCountry.ae:
        return RegExp(r'^05\d{8}$').hasMatch(local);
      case AppCountry.us:
        return RegExp(r'^[2-9]\d{9}$').hasMatch(local);
    }
  }

  /// E.164 form used with Supabase auth (`+964…`, `+971…`, `+1…`).
  String toE164(String input) {
    final local = normalizePhone(input);
    switch (this) {
      case AppCountry.iq:
        return local.startsWith('0')
            ? '$dialCode${local.substring(1)}'
            : '$dialCode$local';
      case AppCountry.ae:
        return local.startsWith('0')
            ? '$dialCode${local.substring(1)}'
            : '$dialCode$local';
      case AppCountry.us:
        return '$dialCode${local.startsWith('1') ? local.substring(1) : local}';
    }
  }

  /// Digits stored in `profiles.phone_number` / `auth.users.phone`
  /// (no plus sign).
  String toStored(String input) => toE164(input).substring(1);

  /// Detects the country of a stored/international phone number.
  static AppCountry fromPhone(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('964')) return AppCountry.iq;
    if (digits.startsWith('971')) return AppCountry.ae;
    if (digits.startsWith('1') && digits.length == 11) return AppCountry.us;
    if (digits.startsWith('07') || digits.length == 11) return AppCountry.iq;
    return AppCountry.iq;
  }

  /// Splits a stored phone into a local part for editing.
  String localFromStored(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('964')) return '0${digits.substring(3)}';
    if (digits.startsWith('971')) return '0${digits.substring(3)}';
    if (digits.startsWith('1') && digits.length == 11) {
      return digits.substring(1);
    }
    return digits;
  }

  /// Groups the number for display, e.g. `0770 123 4567`.
  String prettyPhone(String? phone) {
    final local = localFromStored(phone);
    if (this == AppCountry.iq && local.length == 11) {
      return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
    }
    if (local.length == 10) {
      return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }
    return local.isEmpty ? (phone ?? '') : local;
  }
}
