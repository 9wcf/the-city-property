import 'package:flutter_test/flutter_test.dart';
import 'package:the_city_property/core/widgets/premium_widgets.dart';

void main() {
  group('friendlyError repairs broken Arabic', () {
    test('decodes cp1256 mojibake and explains the duplicate phone', () {
      const broken =
          'PostgrestException(message: ظ‡ط°ط§ ط§ظ„ط±ظ‚ظ… ظ…ط³ط¬ظ„ ظƒظ€ظ…ط§ظ„ظƒ ط¨ط§ظ„ظپط¹ظ„, code: P0001, details: null, hint: null)';
      final message = friendlyError(broken);
      expect(message, contains('مسجل مسبقاً'));
      expect(message, isNot(contains('PostgrestException')));
      expect(message, isNot(contains('ط§ظ„')));
    });

    test('handles a leftover percent placeholder', () {
      const broken =
          'ظ‡ط°ط§ ط§ظ„ط±ظ‚ظ… ظ…ط³ط¬ظ„ ظƒظ€% ط¨ط§ظ„ظپط¹ظ„';
      expect(friendlyError(broken), contains('مسجل مسبقاً'));
    });

    test('never shows unreadable text even if repair fails', () {
      const broken = 'Ø§Ù„Ø´Ù‚Ø© ÙŠØ³Øª ÙپØ§Ø±Ø؛Ø©';
      final message = friendlyError(broken);
      expect(message, 'تعذر تنفيذ العملية. تحقق من البيانات المدخلة وأعد المحاولة.');
    });

    test('maps clean Arabic database messages', () {
      const error =
          'PostgrestException(message: يوجد عقد نشط على هذه الشقة, code: P0001)';
      expect(friendlyError(error), contains('عقد نشط'));
    });

    test('never returns raw exception text', () {
      const error = 'PostgrestException(message: , code: 42)';
      expect(friendlyError(error), 'تعذر تنفيذ العملية. تحقق من البيانات المدخلة وأعد المحاولة.');
    });

    test('keeps short readable messages', () {
      expect(friendlyError(Exception('تعذر الاتصال')), 'تعذر الاتصال');
    });
  });
}
