import 'translations_en.dart';
import 'translations_en_extra.dart';
import 'translations_en_extra_b.dart';
import 'translations_en_extra_c.dart';
import 'translations_en_extra_d.dart';

enum AppLanguage { ar, en }

/// Process-wide language state. Widgets read it through [I18n.translate] (the
/// app rebuilds from the root when the language changes, so no listener is
/// needed here).
class I18n {
  I18n._();

  static AppLanguage language = AppLanguage.ar;

  static bool get isEnglish => language == AppLanguage.en;

  static void setLanguage(AppLanguage value) {
    language = value;
  }

  static String translate(String arabic) => _translate(arabic, 0);

  static String _translate(String arabic, int depth) {
    if (arabic.isEmpty || !isEnglish) return arabic;
    final direct = kEnglishTranslations[arabic] ??
        kEnglishTranslationsExtraA[arabic] ??
        kEnglishTranslationsExtraB[arabic] ??
        kEnglishTranslationsExtraC[arabic] ??
        kEnglishTranslationsExtraD[arabic];
    if (direct != null) return direct;
    if (!_hasArabic(arabic)) return arabic;
    return _dynamic(arabic, depth);
  }

  static String t(String arabic) => translate(arabic);

  static bool _hasArabic(String value) =>
      RegExp('[\u0600-\u06FF]').hasMatch(value);

  static final List<(RegExp, String)> _patterns = [
    // Composed messages
    (RegExp(r'^سيتم ربط (.+) بـ(.+) وتحويل حالتها إلى مؤجرة\. هل تريد المتابعة؟$'),
        'Link \$1 to \$2 and mark it as rented. Continue?'),
    (RegExp(r'^مرحباً (.+)، بخصوص سجل إيجار (.+)$'),
        'Hello \$1, regarding the rent record for \$2'),
    (RegExp(r'^مرحباً (.+)، بخصوص إيجار (.+)$'),
        'Hello \$1, regarding the rent for \$2'),
    (RegExp(r'^مرحباً (.+)، بخصوص (.+)$'),
        'Hello \$1, regarding \$2'),
    (RegExp(r'^مرحباً، أنا (.+) من (.*)$'), 'Hello, I am \$1 from \$2'),
    (RegExp(r'^مرحباً، أرغب بتسديد إيجار (.+)$'),
        'Hello, I would like to pay the rent for \$1'),
    (RegExp(r'^مرحباً،\s+(.+)$'), 'Welcome, \$1'),

    // Counts and summaries
    (RegExp(r'^([\d,]+)\s+من\s+([\d,]+)\s+شقة مؤجرة$'),
        '\$1 of \$2 occupied apartments'),
    (RegExp(r'^([\d,]+)\s+من\s+([\d,]+)\s+شقة$'),
        '\$1 of \$2 apartments'),
    (RegExp(r'^([\d,]+)\s+من\s+([\d,]+)\s+وحدة$'), '\$1 of \$2 units'),
    (RegExp(r'^([\d,]+)\s+شقة\s+·\s+([\d,]+)\s+طابق\s+·\s+عقار\s+(.+)$'),
        '\$1 apartments · \$2 floors · property \$3'),
    (RegExp(r'^([\d,]+)\s+طوابق\s+·\s+([\d,]+)\s+شقة$'),
        '\$1 floors · \$2 apartments'),
    (RegExp(r'^([\d,]+)\s+بناية\s+·\s+([\d,]+)\s+وحدة$'),
        '\$1 buildings · \$2 units'),
    (RegExp(r'^([\d,]+)\s+عقار\s+·\s+([\d,]+)\s+عمارة\s+·\s+([\d,]+)\s+شقة$'),
        '\$1 properties · \$2 buildings · \$3 apartments'),
    (RegExp(r'^([\d,]+)/([\d,]+)\s+مشغولة$'), '\$1/\$2 occupied'),
    (RegExp(r'^(.+)\s·\sالإيجار\s(.+)$'), '\$1 · rent \$2'),
    (RegExp(r'^([\d,]+)\s+عمارة تحت إدارتك$'),
        '\$1 buildings under your management'),
    (RegExp(r'^([\d,]+)\s+مستأجر مرتبط بمحفظتك$'),
        '\$1 tenants linked to your portfolio'),
    (RegExp(r'^([\d,]+)\s+وحدة جاهزة للتأجير$'),
        '\$1 units ready to rent'),
    (RegExp(r'^([\d,]+)\s+مستأجر لم يسدد إيجار هذا الشهر بعد$'),
        '\$1 tenants have not paid this month rent yet'),
    (RegExp(r'^([\d,]+)\s+طلب يحتاج قراراً$'),
        '\$1 requests need a decision'),
    (RegExp(r'^([\d,]+)\s+مستأجر نشط$'), '\$1 active tenants'),
    (RegExp(r'^([\d,]+)\s+فاتورة مطابقة$'), '\$1 matching invoices'),
    (RegExp(r'^([\d,]+)\s+فاتورة أخرى…$'), '\$1 more invoices…'),
    (RegExp(r'^([\d,]+)\s+شقة عليها متأخرات$'),
        '\$1 apartments with arrears'),
    (RegExp(r'^([\d,]+)\s+إشعار غير مقروء$'),
        '\$1 unread notifications'),
    (RegExp(r'^([\d,]+)\s+طلب مسجل$'), '\$1 recorded requests'),
    (RegExp(r'^([\d,]+)\s+سجل محفوظ بالكامل$'),
        '\$1 fully archived records'),
    (RegExp(r'^([\d,]+)\s+سجل — الحذف النهائي متاح للمالك فقط ويشمل العقد والدفعات والمستمسكات$'),
        '\$1 records — permanent deletion is owner-only and includes the '
            'lease, payments and documents'),
    (RegExp(r'^([\d,]+)\s+عضو مطابق$'), '\$1 matching members'),
    (RegExp(r'^([\d,]+)\s+طلب صيانة$'),
        '\$1 maintenance requests'),
    (RegExp(r'^([\d,]+)\s+طلب بانتظار الموافقة$'),
        '\$1 requests awaiting approval'),
    (RegExp(r'^([\d,]+)\s+طلب بانتظار قرارك$'),
        '\$1 requests awaiting your decision'),
    (RegExp(r'^([\d,]+)\s+طلب مفتوح$'), '\$1 open requests'),
    (RegExp(r'^([\d,]+)\s+عاجل$'), '\$1 urgent'),
    (RegExp(r'^([\d,]+)\s+دفعة مسجلة$'), '\$1 recorded payments'),
    (RegExp(r'^([\d,]+)\s+وحدة فارغة$'), '\$1 vacant units'),
    (RegExp(r'^([\d,]+)\s+مستأجر$'), '\$1 tenants'),
    (RegExp(r'^([\d,]+)\s+شقة$'), '\$1 apartments'),
    (RegExp(r'^([\d,]+)\s+عمارة$'), '\$1 buildings'),
    (RegExp(r'^([\d,]+)\s+عقار$'), '\$1 properties'),
    (RegExp(r'^([\d,]+)\s+بناية$'), '\$1 buildings'),
    (RegExp(r'^([\d,]+)\s+وحدة$'), '\$1 units'),
    (RegExp(r'^([\d,]+)\s+فاتورة$'), '\$1 invoices'),
    (RegExp(r'^([\d,]+)\s+دفعة$'), '\$1 payments'),
    (RegExp(r'^([\d,]+)\s+طلب$'), '\$1 requests'),
    (RegExp(r'^([\d,]+)\s+صورة$'), '\$1 photos'),
    (RegExp(r'^([\d,]+)\s+غرف$'), '\$1 rooms'),
    (RegExp(r'^([\d,]+)\s+دول$'), '\$1 countries'),
    (RegExp(r'^([\d,]+)\s+م²$'), '\$1 m²'),
    (RegExp(r'^([\d,]+)\s+سجل$'), '\$1 records'),
    (RegExp(r'^([\d,]+)\s+عضو$'), '\$1 members'),
    (RegExp(r'^([\d,]+)\s+فاتورة متأخرة$'), '\$1 overdue invoices'),
    (RegExp(r'^([\d,]+)\s+عملية$'), '\$1 transactions'),
    (RegExp(r'^([\d,]+)\s+أشهر$'), '\$1 months'),
    (RegExp(r'^([\d,]+)\s+شهر$'), '\$1 months'),
    (RegExp(r'^([\d,]+)\s+من\s+([\d,]+)\s+·\s+([\d,]+)\s+مستأجر$'),
        '\$1 of \$2 · \$3 tenants'),

    // Prefix + value labels
    (RegExp(r'^أدخل رقماً صحيحاً لـ(.+) \((.+)\)$'),
        'Enter a valid number for \$1 (\$2)'),
    (RegExp(r'^رقم غير صالح لـ(.+) \((.+)\)$'),
        'Invalid number for \$1 (\$2)'),
    (RegExp(r'^رقم الهاتف \((.+)\)$'), 'Phone number (\$1)'),
    (RegExp(r'^أرسلنا رمزاً مكوّناً من 6 أرقام إلى (.+)$'),
        'We sent a 6-digit code to \$1'),
    (RegExp(r'^أولوية (.+)$'), 'Priority: \$1'),
    (RegExp(r'^إضافة المزيد \(([\d/]+)\)$'), 'Add more (\$1)'),
    (RegExp(r'^إعادة الإرسال بعد (.+) ثانية$'),
        'Resend in \$1 seconds'),
    (RegExp(r'^استحقاق (.+)$'), 'Due \$1'),
    (RegExp(r'^الأرشيف \(([\d,]+)\)$'), 'Archive (\$1)'),
    (RegExp(r'^الإيراد (.+)$'), 'Revenue \$1'),
    (RegExp(r'^البيئة: (.+)$'), 'Environment: \$1'),
    (RegExp(r'^العملة: (.+)$'), 'Currency: \$1'),
    (RegExp(r'^الحد الأقصى (.+) صورة لكل قسم$'),
        'Maximum \$1 photos per section'),
    (RegExp(r'^المتبقي (.+)$'), 'Remaining \$1'),
    (RegExp(r'^المدفوع هذا الشهر (.+)$'), 'Paid this month \$1'),
    (RegExp(r'^المستأجر: (.+)$'), 'Tenant: \$1'),
    (RegExp(r'^المستلم هذا الشهر (.+)$'), 'Received this month \$1'),
    (RegExp(r'^النشطون \(([\d,]+)\)$'), 'Active (\$1)'),
    (RegExp(r'^انتهى منذ (.+) يوم$'), 'Ended \$1 days ago'),
    (RegExp(r'^تأخير (.+) يوم$'), 'Overdue by \$1 days'),
    (RegExp(r'^بخصوص طلب الصيانة: (.+)$'),
        'About maintenance request: \$1'),
    (RegExp(r'^تاريخ الاستحقاق (.+)$'), 'Due date \$1'),
    (RegExp(r'^تحصيل (.+)$'), 'Collection \$1'),
    (RegExp(r'^تسجيل دفعة · (.+)$'), 'Record payment · \$1'),
    (RegExp(r'^تسجيل دفعة — (.+)$'), 'Record payment — \$1'),
    (RegExp(r'^تعذر اختيار الصور: (.+)$'),
        'Could not pick photos: \$1'),
    (RegExp(r'^تعذر رفع الصور: (.+)$'),
        'Could not upload photos: \$1'),
    (RegExp(r'^تقرير البنايات — (.+)$'), 'Buildings report — \$1'),
    (RegExp(r'^تم إرسال الإشعار إلى (.+) مستخدماً$'),
        'Notification sent to \$1 users'),
    (RegExp(r'^تم إضافة المستأجر ورفع (.+) صورة بنجاح$'),
        'Tenant added and \$1 photos uploaded successfully'),
    (RegExp(r'^تم إضافة المستأجر، لكن تعذر رفع (.+) صورة\. يمكنك إضافتها لاحقاً من بطاقة المستأجر\.$'),
        'Tenant added, but \$1 photos could not be uploaded. You can add '
            'them later from the tenant card.'),
    (RegExp(r'^تم التحصيل خلال (.+)$'), 'Collected during \$1'),
    (RegExp(r'^تم تحديث كلمة مرور (.+)$'), 'Password updated for \$1'),
    (RegExp(r'^تم توليد (.+) فاتورة$'), '\$1 invoices generated'),
    (RegExp(r'^تم حذف (.+) نهائياً$'), '\$1 was deleted permanently'),
    (RegExp(r'^تم رفع (.+) صورة وتعذر رفع (.+) صورة$'),
        '\$1 photos uploaded and \$2 failed'),
    (RegExp(r'^تم رفع (.+) صورة بنجاح$'),
        '\$1 photos uploaded successfully'),
    (RegExp(r'^تمت إضافة أول (.+) صورة فقط$'),
        'Only the first \$1 photos were added'),
    (RegExp(r'^تمت ترقية الحساب إلى (.+)$'),
        'Account upgraded to \$1'),
    (RegExp(r'^خرج في (.+)$'), 'Moved out on \$1'),
    (RegExp(r'^دخول لوحة (.+)$'), 'Open \$1 dashboard'),
    (RegExp(r'^رقم الوصل: (.+)$'), 'Receipt number: \$1'),
    (RegExp(r'^ساري حتى (.+)$'), 'Valid until \$1'),
    (RegExp(r'^سدد (.+)$'), 'Paid \$1'),
    (RegExp(r'^سيتم إنشاء فواتير لجميع العقود النشطة لشهر (.+)، مع تجاوز العقود التي لديها فاتورة لهذا الشهر بالفعل\.$'),
        'Invoices will be created for all active leases for \$1, skipping '
            'leases that already have an invoice this month.'),
    (RegExp(r'^سيتم حذف (.+) نهائياً\. لا يمكن التراجع\.$'),
        '\$1 will be permanently deleted. This cannot be undone.'),
    (RegExp(r'^سيتم حذف «(.+)» نهائياً مع:$'),
        'Permanently delete "\$1" along with:'),
    (RegExp(r'^سيتم حذف العمارة «(.+)» وكل طوابقها وشققها \(([\d,]+) شقة\)\. لا يمكن التراجع\.$'),
        'Delete building "\$1" with all its floors and its \$2 apartments. '
            'This cannot be undone.'),
    (RegExp(r'^سيتم منع (.+) من الدخول إلى النظام مع الاحتفاظ بكل بياناته\.$'),
        '\$1 will be blocked from signing in while all data is retained.'),
    (RegExp(r'^سيتمكن (.+) من الدخول إلى النظام مرة أخرى\.$'),
        '\$1 will be able to sign in again.'),
    (RegExp(r'^شقق عمارة (.+)$'), 'Apartments of building \$1'),
    (RegExp(r'^صافي (.+)$'), 'Net \$1'),
    (RegExp(r'^عام · (.+)$'), 'General · \$1'),
    (RegExp(r'^عمارات (.+) · نظرة سريعة على الإشغال$'),
        '\$1 buildings · occupancy snapshot'),
    (RegExp(r'^عمارات عقار (.+) · (.+) (.+)$'),
        'Buildings of property \$1 · \$2 \$3'),
    (RegExp(r'^عقارات (.+)$'), '\$1 properties'),
    (RegExp(r'^عيّن مديراً لعقار كامل أو لشقة محددة في (.+)، وراجع التغطية الحالية$'),
        'Assign a manager to a whole property or a specific apartment in '
            '\$1, and review current coverage'),
    (RegExp(r'^فواتير الإيجار والتحصيل والمصروفات وصافي الدخل لشهر (.+) · (.+)$'),
        'Rent invoices, collections, expenses and net income for \$1 · \$2'),
    (RegExp(r'^الإيجار الشهري \((.+)\)$'), 'Monthly rent (\$1)'),
    (RegExp(r'^المبلغ المستلم \((.+)\)$'), 'Amount received (\$1)'),
    (RegExp(r'^الكلفة \((.+)\)$'), 'Cost (\$1)'),
    (RegExp(r'^فاتورة (.+) · (.+) متبقٍ$'),
        'Invoice \$1 · \$2 remaining'),
    (RegExp(r'^فاتورة (.+)$'), 'Invoice \$1'),
    (RegExp(r'^فواتير (.+)$'), 'Invoices \$1'),
    (RegExp(r'^كلمة مرور (.+)$'), 'Password for \$1'),
    (RegExp(r'^لم تُسجل دفعة خلال (.+)$'),
        'No payment recorded during \$1'),
    (RegExp(r'^متبقي (.+) يوم$'), '\$1 days left'),
    (RegExp(r'^محصّل (.+)$'), 'Collected \$1'),
    (RegExp(r'^محفظتك: (.+) عقار · (.+) شقة في ثلاث دول$'),
        'Your portfolio: \$1 properties · \$2 apartments in three countries'),
    (RegExp(r'^مدفوعات (.+)$'), 'Payments \$1'),
    (RegExp(r'^مديرو (.+)$'), 'Managers of \$1'),
    (RegExp(r'^مسؤول عن: (.+)$'), 'Responsible for: \$1'),
    (RegExp(r'^مستحق (.+)$'), 'Due \$1'),
    (RegExp(r'^مصاريف (.+)$'), 'Expenses \$1'),
    (RegExp(r'^مصروفات شهر (.+)$'), 'Monthly expenses \$1'),
    (RegExp(r'^مقدم الطلب: (.+)$'), 'Requested by: \$1'),
    (RegExp(r'^ملخص تنفيذي لأداء (.+) عقار و(.+) وحدة سكنية في (.+)$'),
        'Executive summary for \$1 properties and \$2 residential units in '
            '\$3'),
    (RegExp(r'^منتهي منذ (.+) يوم$'), 'Expired \$1 days ago'),
    (RegExp(r'^نسبة التحصيل من المتوقع (.+)$'),
        'Collection rate of expected \$1'),
    (RegExp(r'^نسبة التحصيل (.+)$'), 'Collection rate \$1'),
    (RegExp(r'^نسبة (.+)$'), 'Rate \$1'),
    (RegExp(r'^هل تريد إزالة تعيين (.+) عن هذا العقار؟ لن يتمكن من رؤية طلباته بعد ذلك\.$'),
        'Remove the assignment of \$1 from this property? They will no '
            'longer see its requests.'),
    (RegExp(r'^هل تريد إزالة تعيين (.+) عن (.+)؟$'),
        'Remove the assignment of \$1 from \$2?'),
    (RegExp(r'^هل تريد حذف «(.+)» بقيمة (.+)؟$'),
        'Delete "\$1" with a value of \$2?'),
    (RegExp(r'^هل تريد حذف «(.+)»؟$'), 'Delete "\$1"?'),
    (RegExp(r'^هل توافق على كلفة (.+) لهذا الطلب؟$'),
        'Approve the cost of \$1 for this request?'),
    (RegExp(r'^• الدفعات \(([\d,]+)\) بإجمالي (.+)$'),
        '• Payments (\$1) totaling \$2'),
    (RegExp(r'^أرسل إشعارات فورية للمستأجرين والمديرين في (.+) داخل التطبيق وعلى هواتفهم$'),
        'Send instant notifications to tenants and managers in \$1 in the '
            'app and on their phones'),
    (RegExp(r'^تحكم كامل في المستأجرين والمديرين في (.+): التفعيل، تعيين النطاق، وكلمات المرور$'),
        'Full control over tenants and managers in \$1: activation, scoping '
            'and passwords'),
    (RegExp(r'^المستأجرون الحاليون وسجل المستأجرين المؤرشفين في (.+) — الحذف النهائي متاح للمالك فقط$'),
        'Current tenants and archived tenant records in \$1 — permanent '
            'deletion is owner-only'),
    (RegExp(r'^الحد الأقصى (.+) صورة$'), 'Maximum \$1 photos'),
    (RegExp(r'^و(.+) فاتورة أخرى…$'), 'and \$1 more invoices…'),

    // Generic unit labels
    (RegExp(r'^شقة\s+(.+)$'), 'Apt \$1'),
    (RegExp(r'^شقة$'), 'Apt'),
    (RegExp(r'^عمارة\s+(.+)$'), 'Building \$1'),
    (RegExp(r'^عمارة$'), 'Building'),
    (RegExp(r'^مجمع\s+(.+)$'), 'Complex \$1'),
    (RegExp(r'^الطابق الأرضي$'), 'Ground floor'),
    (RegExp(r'^الطابق\s+(.+)$'), 'Floor \$1'),
    (RegExp(r'^طابق\s+(.+)$'), 'Floor \$1'),
    (RegExp(r'^باقي\s+(.+)\s+أيام$'), '\$1 days left'),
    (RegExp(r'^باقي\s+(.+)\s+يوماً$'), '\$1 days left'),
    (RegExp(r'^باقي\s+(.+)\s+يوم$'), '\$1 days left'),
    (RegExp(r'^متأخر\s+(.+)\s+يوم$'), '\$1 days overdue'),
    (RegExp(r'^قبل\s+(.+)\s+دقيقة$'), '\$1 min ago'),
    (RegExp(r'^قبل\s+(.+)\s+ساعة$'), '\$1 h ago'),
    (RegExp(r'^قبل\s+(.+)\s+يوم$'), '\$1 d ago'),
    (RegExp(r'^(.+)\s+مليون$'), '\$1M'),
    (RegExp(r'^(.+)\s+ألف$'), '\$1K'),
    (RegExp(r'^(.+)\s+متبقٍ$'), '\$1 remaining'),
    (RegExp(r'^(.+)\s+/\s+شهرياً$'), '\$1 / month'),
  ];

  static const Map<String, String> _words = {
    'شقة': 'Apt',
    'شقه': 'Apt',
    'الشقة': 'Apt',
    'عمارة': 'Building',
    'العمارة': 'Building',
    'مجمع': 'Complex',
    'المجمع': 'Complex',
    'طابق': 'Floor',
    'الطابق': 'Floor',
    'مؤجرة': 'Occupied',
    'فارغة': 'Vacant',
    'محجوزة': 'Reserved',
    'صيانة': 'Maintenance',
    'مالك': 'Owner',
    'مدير': 'Manager',
    'مستأجر': 'Tenant',
    'د.ع': 'IQD',
    'د.إ': 'AED',
    'الآن': 'Just now',
    'أمس': 'Yesterday',
    'اليوم': 'Today',
    'شهر': 'month',
    'سنة': 'year',
    'أيام': 'days',
    'يوم': 'day',
  };

  static final List<MapEntry<String, String>> _wordsByLength =
      _words.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static String _dynamic(String text, int depth) {
    for (final (pattern, replacement) in _patterns) {
      if (pattern.hasMatch(text)) {
        return text.replaceFirstMapped(pattern, (m) {
          var out = replacement;
          for (var i = 1; i < m.groupCount + 1; i++) {
            final group = m.group(i) ?? '';
            out = out.replaceAll(
              '\$$i',
              depth < 3 ? _translate(group, depth + 1) : group,
            );
          }
          return out;
        });
      }
    }
    // Word-level fallback for mixed labels such as "شقة 101 · عمارة A".
    var out = text;
    var changed = false;
    for (final entry in _wordsByLength) {
      final word = RegExp(
        '(?<![\u0600-\u06FF])${RegExp.escape(entry.key)}(?![\u0600-\u06FF])',
      );
      if (word.hasMatch(out)) {
        out = out.replaceAll(word, entry.value);
        changed = true;
      }
    }
    return changed ? out : text;
  }
}

/// Short alias used across the UI: `tr('نص')`.
String tr(String arabic) => I18n.translate(arabic);
