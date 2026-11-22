import 'package:flutter_test/flutter_test.dart';
import 'package:the_city_property/core/utils/app_utils.dart';
import 'package:the_city_property/data/models.dart';

void main() {
  group('apartmentDisplayName', () {
    test('prefixes bare numbers', () {
      expect(apartmentDisplayName('101'), 'شقة 101');
    });

    test('keeps a written name as-is', () {
      expect(apartmentDisplayName('شقة رقم واحد'), 'شقة رقم واحد');
      expect(apartmentDisplayName('شقه رقم واحد'), 'شقه رقم واحد');
      expect(apartmentDisplayName('الوحدة الأرضية'), 'الوحدة الأرضية');
    });

    test('falls back for empty values', () {
      expect(apartmentDisplayName(null), 'شقة');
      expect(apartmentDisplayName('  '), 'شقة');
    });
  });

  group('Apartment floor label', () {
    test('prefers the written floor name', () {
      const apartment = Apartment(
        id: 'a',
        floorId: 'f',
        unitNumber: 'شقة رقم واحد',
        rentAmount: 0,
        status: ApartmentStatus.vacant,
        floorNumber: 1,
        floorLabelText: 'الطابق الأول - فوق المحلات',
      );
      expect(apartment.floorLabel, 'الطابق الأول - فوق المحلات');
    });

    test('falls back to the numeric floor', () {
      const apartment = Apartment(
        id: 'a',
        floorId: 'f',
        unitNumber: '1',
        rentAmount: 0,
        status: ApartmentStatus.vacant,
        floorNumber: 0,
      );
      expect(apartment.floorLabel, 'الطابق الأرضي');
    });
  });

  group('addMonthsClamped', () {
    test('clamps the day to the end of the target month', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('adds standard durations across a year boundary', () {
      expect(addMonthsClamped(DateTime(2026, 11, 7), 3), DateTime(2027, 2, 7));
      expect(addMonthsClamped(DateTime(2026, 11, 7), 12), DateTime(2027, 11, 7));
    });
  });

  test('leaseDurationLabel reads naturally', () {
    expect(leaseDurationLabel(1), 'شهر');
    expect(leaseDurationLabel(3), '3 أشهر');
    expect(leaseDurationLabel(6), '6 أشهر');
    expect(leaseDurationLabel(12), 'سنة');
  });
}
