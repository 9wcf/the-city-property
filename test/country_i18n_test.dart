import 'package:flutter_test/flutter_test.dart';
import 'package:the_city_property/core/i18n/app_country.dart';
import 'package:the_city_property/core/i18n/i18n.dart';
import 'package:the_city_property/core/utils/app_utils.dart';

void main() {
  group('country phones', () {
    test('Iraq local and international forms normalize', () {
      expect(AppCountry.iq.normalizePhone('07701234567'), '07701234567');
      expect(AppCountry.iq.normalizePhone('+9647701234567'), '07701234567');
      expect(AppCountry.iq.normalizePhone('7701234567'), '07701234567');
      expect(AppCountry.iq.toStored('07701234567'), '9647701234567');
    });

    test('UAE local and international forms normalize', () {
      expect(AppCountry.ae.normalizePhone('0501234567'), '0501234567');
      expect(AppCountry.ae.normalizePhone('+971501234567'), '0501234567');
      expect(AppCountry.ae.normalizePhone('501234567'), '0501234567');
      expect(AppCountry.ae.toStored('0501234567'), '971501234567');
    });

    test('US local and international forms normalize', () {
      expect(AppCountry.us.normalizePhone('4155550123'), '4155550123');
      expect(AppCountry.us.normalizePhone('+14155550123'), '4155550123');
      expect(AppCountry.us.toStored('4155550123'), '14155550123');
    });

    test('validation rejects numbers from another country', () {
      expect(AppCountry.iq.isValidPhone('07701234567'), isTrue);
      expect(AppCountry.iq.isValidPhone('0501234567'), isFalse);
      expect(AppCountry.ae.isValidPhone('0501234567'), isTrue);
      expect(AppCountry.ae.isValidPhone('07701234567'), isFalse);
      expect(AppCountry.us.isValidPhone('4155550123'), isTrue);
      expect(AppCountry.us.isValidPhone('07701234567'), isFalse);
    });

    test('stored phone round-trips through country detection', () {
      for (final country in AppCountry.values) {
        final local = country.phoneHint;
        expect(AppCountry.fromPhone(country.toStored(local)), country);
      }
    });
  });

  group('currency', () {
    test('each country uses its own symbol', () {
      I18n.setLanguage(AppLanguage.ar);
      expect(formatMoney(1500, withCurrency: true, country: AppCountry.iq),
          contains('د.ع'));
      expect(formatMoney(1500, withCurrency: true, country: AppCountry.ae),
          contains('د.إ'));
      expect(formatMoney(1500, withCurrency: true, country: AppCountry.us),
          startsWith('\$'));
    });

    test('english mode uses latin currency codes', () {
      I18n.setLanguage(AppLanguage.en);
      expect(formatMoney(1500, withCurrency: true, country: AppCountry.iq),
          contains('IQD'));
      I18n.setLanguage(AppLanguage.ar);
    });
  });

  group('translations', () {
    tearDown(() => I18n.setLanguage(AppLanguage.ar));

    test('arabic stays untouched', () {
      expect(I18n.translate('نظرة عامة'), 'نظرة عامة');
    });

    test('english dictionary and dynamic patterns', () {
      I18n.setLanguage(AppLanguage.en);
      expect(I18n.translate('نظرة عامة'), 'Overview');
      expect(I18n.translate('شقة 12'), 'Apt 12');
      expect(I18n.translate('مرحباً، أحمد'), 'Welcome, أحمد');
      expect(I18n.translate('3 فاتورة متأخرة'), '3 overdue invoices');
    });
  });
}
