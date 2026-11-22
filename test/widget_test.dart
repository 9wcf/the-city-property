import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:the_city_property/core/utils/app_utils.dart';

void main() {
  group('phone helpers', () {
    test('normalizes Iraqi numbers', () {
      expect(normalizeLocalPhone('07701234567'), '07701234567');
      expect(normalizeLocalPhone('+9647701234567'), '07701234567');
      expect(normalizeLocalPhone('9647701234567'), '07701234567');
      expect(normalizeLocalPhone('7701234567'), '07701234567');
      expect(toE164Iraq('07701234567'), '+9647701234567');
    });

    test('validates Iraqi mobile numbers', () {
      expect(isValidIraqiPhone('07701234567'), isTrue);
      expect(isValidIraqiPhone('12345'), isFalse);
    });
  });

  test('formats money', () {
    expect(formatMoney(500000), '500,000');
    expect(formatMoney(1500000, withCurrency: true), '1,500,000 د.ع');
  });

  test('isoDate stays ASCII under the Arabic locale', () {
    Intl.defaultLocale = 'ar';
    expect(isoDate(DateTime(2026, 11, 1)), '2026-11-01');
    expect(isoDate(DateTime(2027, 1, 5)), '2027-01-05');
    Intl.defaultLocale = 'en';
  });
}
