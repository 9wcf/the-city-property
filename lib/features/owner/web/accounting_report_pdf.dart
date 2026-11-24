import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/i18n/app_country.dart';
import '../../../data/models.dart';

class AccountingReportData {
  const AccountingReportData({
    required this.ownerName,
    required this.month,
    required this.country,
    required this.invoices,
    required this.expenses,
    required this.payments,
  });

  final String ownerName;
  final DateTime month;
  final AppCountry country;
  final List<Invoice> invoices;
  final List<Expense> expenses;
  final List<Payment> payments;
}

const _navy = PdfColor.fromInt(0xFF0B1324);
const _navySoft = PdfColor.fromInt(0xFF19223B);
const _gold = PdfColor.fromInt(0xFFC9A227);
const _goldSoft = PdfColor.fromInt(0xFFF6EDD2);
const _ink = PdfColor.fromInt(0xFF111827);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE2E6EF);
const _soft = PdfColor.fromInt(0xFFF7F8FA);
const _green = PdfColor.fromInt(0xFF1F8A4C);
const _red = PdfColor.fromInt(0xFFB42318);
const _amber = PdfColor.fromInt(0xFFB54708);

const _monthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String _two(int value) => value.toString().padLeft(2, '0');

String _date(DateTime date) => '${date.year}/${_two(date.month)}/${_two(date.day)}';

String _period(DateTime month) => '${_monthNames[month.month - 1]} ${month.year}';

String _num(num value) {
  final negative = value < 0;
  final fixed =
      value.abs().toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}$buffer$decimals';
}

String _money(num value, AppCountry country) =>
    '${_num(value)} ${country.currencyAr}';

String _percent(num part, num whole) =>
    whole <= 0 ? '0%' : '${(part / whole * 100).round()}%';

PdfColor _statusColor(Invoice invoice) {
  if (invoice.isPaid) return _green;
  if (invoice.isOverdue) return _red;
  if (invoice.status == 'partial') return _amber;
  return _muted;
}

Future<Uint8List> buildAccountingReportPdf(AccountingReportData data) async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
  );

  final invoices = [...data.invoices]
    ..sort((a, b) => a.number.compareTo(b.number));
  final expenses = [...data.expenses]
    ..sort((a, b) => a.date.compareTo(b.date));
  final payments = [...data.payments]
    ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

  final billed = invoices.fold<double>(0, (sum, i) => sum + i.totalAmount);
  final collected = invoices.fold<double>(0, (sum, i) => sum + i.paidAmount);
  final outstanding = invoices.fold<double>(0, (sum, i) => sum + i.remaining);
  final rent = invoices.fold<double>(0, (sum, i) => sum + i.rentAmount);
  final utilities = invoices.fold<double>(0, (sum, i) => sum + i.utilitiesAmount);
  final maintenance =
      invoices.fold<double>(0, (sum, i) => sum + i.maintenanceAmount);
  final other = invoices.fold<double>(0, (sum, i) => sum + i.otherCharges);
  final expensesTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final received = payments.fold<double>(0, (sum, p) => sum + p.amount);
  final net = collected - expensesTotal;
  final overdue = invoices.where((i) => i.isOverdue).length;
  final partial = invoices
      .where((i) => !i.isPaid && i.status == 'partial')
      .length;

  final compoundRows = <String, List<double>>{};
  for (final invoice in invoices) {
    final key = (invoice.compoundName ?? 'بدون عقار').trim();
    final row = compoundRows.putIfAbsent(key, () => [0, 0, 0, 0]);
    row[0] += 1;
    row[1] += invoice.totalAmount;
    row[2] += invoice.paidAmount;
    row[3] += invoice.remaining;
  }
  final expenseByCompound = <String, double>{};
  for (final expense in expenses) {
    final key = (expense.compoundName ?? 'بدون عقار').trim();
    expenseByCompound[key] = (expenseByCompound[key] ?? 0) + expense.amount;
  }
  final compounds = <String>{
    ...compoundRows.keys,
    ...expenseByCompound.keys,
  }.toList()
    ..sort();

  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  final headerStyle = pw.TextStyle(
    font: bold,
    fontSize: 7,
    color: PdfColors.white,
  );
  final cellStyle = pw.TextStyle(font: regular, fontSize: 7, color: _ink);
  final totalsStyle = pw.TextStyle(font: bold, fontSize: 7, color: _navy);

  final tableBorder = pw.TableBorder(
    horizontalInside: const pw.BorderSide(color: _line, width: .4),
    bottom: const pw.BorderSide(color: _line, width: .6),
  );

  pw.Widget sectionTitle(String title, {String? subtitle}) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 7),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 3, height: 13, color: _gold),
            pw.SizedBox(width: 6),
            pw.Text(
              title,
              style: pw.TextStyle(font: bold, fontSize: 10.5, color: _navy),
            ),
            if (subtitle != null) ...[
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  subtitle,
                  style: pw.TextStyle(font: regular, fontSize: 7, color: _muted),
                ),
              ),
            ],
          ],
        ),
      );

  pw.Widget kpi(String label, String value, String caption, PdfColor accent) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          color: _soft,
          border: pw.Border(
            right: pw.BorderSide(color: accent, width: 2.2),
            top: const pw.BorderSide(color: _line, width: .4),
            left: const pw.BorderSide(color: _line, width: .4),
            bottom: const pw.BorderSide(color: _line, width: .4),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(font: regular, fontSize: 7, color: _muted),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(font: bold, fontSize: 11.5, color: accent),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              caption,
              style: pw.TextStyle(font: regular, fontSize: 6.3, color: _muted),
            ),
          ],
        ),
      );

  pw.Widget kpiRow(List<pw.Widget> cards) => pw.Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) pw.SizedBox(width: 7),
            pw.Expanded(child: cards[i]),
          ],
        ],
      );

  pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    required Map<int, pw.TableColumnWidth> widths,
    List<PdfColor>? statusColors,
    bool emphasizeLastRow = false,
    String emptyText = 'لا توجد بيانات لهذا الشهر',
    Map<int, pw.AlignmentGeometry>? alignments,
  }) {
    if (rows.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: _soft,
          border: pw.Border.all(color: _line, width: .4),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          emptyText,
          style: pw.TextStyle(font: regular, fontSize: 8, color: _muted),
          textAlign: pw.TextAlign.center,
        ),
      );
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: widths,
      tableDirection: pw.TextDirection.rtl,
      headerDirection: pw.TextDirection.rtl,
      headerDecoration: const pw.BoxDecoration(color: _navySoft),
      headerStyle: headerStyle,
      headerAlignment: pw.Alignment.center,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      cellStyle: cellStyle,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: alignments,
      border: tableBorder,
      oddRowDecoration: const pw.BoxDecoration(color: _soft),
      cellDecoration: emphasizeLastRow
          ? (column, cell, rowNum) => rowNum == rows.length
              ? const pw.BoxDecoration(color: _goldSoft)
              : const pw.BoxDecoration()
          : null,
      textStyleBuilder: emphasizeLastRow
          ? (column, cell, rowNum) =>
              rowNum == rows.length ? totalsStyle : cellStyle
          : null,
      cellBuilder: statusColors == null
          ? null
          : (column, cell, rowNum) {
              if (column != headers.length - 1) return null;
              final index = rowNum - 1;
              final color = index >= 0 && index < statusColors.length
                  ? statusColors[index]
                  : _ink;
              return pw.Text(
                cell.toString(),
                style: cellStyle.copyWith(
                  color: color,
                  fontWeight: pw.FontWeight.bold,
                ),
              );
            },
    );
  }

  pw.Widget signature(String title) => pw.Expanded(
        child: pw.Container(
          height: 58,
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _line, width: .5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(font: bold, fontSize: 7.5, color: _navy),
              ),
              pw.Text(
                'الاسم: ____________________',
                style: pw.TextStyle(font: regular, fontSize: 6.5, color: _muted),
              ),
              pw.Text(
                'التوقيع: __________________',
                style: pw.TextStyle(font: regular, fontSize: 6.5, color: _muted),
              ),
            ],
          ),
        ),
      );

  final document = pw.Document(
    title: 'التقرير المحاسبي — ${_period(data.month)}',
    author: 'The City Property',
    creator: 'The City Property',
    subject: 'تقرير محاسبي شهري',
  );

  final pageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 20),
    theme: theme,
    textDirection: pw.TextDirection.rtl,
    buildBackground: (context) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Container(
        color: PdfColors.white,
        child: pw.Container(
          margin: const pw.EdgeInsets.only(top: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _gold, width: 5)),
          ),
        ),
      ),
    ),
  );

  document.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      maxPages: 200,
      header: (context) {
        final first = context.pageNumber == 1;
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 4),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: .7)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logo,
                      width: first ? 40 : 22, height: first ? 40 : 22),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      first
                          ? 'التقرير المحاسبي الشهري'
                          : 'التقرير المحاسبي — ${_period(data.month)}',
                      textAlign: pw.TextAlign.right,
                      textDirection: pw.TextDirection.rtl,
                      overflow: pw.TextOverflow.visible,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: first ? 13 : 9,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
              ),
              if (first) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'لصالح: ${data.ownerName}',
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 8,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  '${data.country.nameAr} · ${_period(data.month)} · العملة ${data.country.currencyAr} · صادر بتاريخ ${_date(DateTime.now())}',
                  textAlign: pw.TextAlign.right,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 7.3,
                    color: _muted,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: .5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'تقرير داخلي أُعد آلياً من بيانات نظام The City Property',
              style: pw.TextStyle(font: regular, fontSize: 6.3, color: _muted),
            ),
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: pw.TextStyle(font: bold, fontSize: 6.5, color: _navy),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 8),
        kpiRow([
          kpi('إجمالي المفوتر', _money(billed, data.country),
              '${invoices.length} فاتورة', _navy),
          kpi('المحصّل من فواتير الشهر', _money(collected, data.country),
              'نسبة التحصيل ${_percent(collected, billed)}', _green),
          kpi('المتبقي على المستأجرين', _money(outstanding, data.country),
              '$overdue فاتورة متأخرة · $partial جزئية', _red),
          kpi('المصروفات', _money(expensesTotal, data.country),
              '${expenses.length} قيد مصروف', _amber),
          kpi('صافي الشهر', _money(net, data.country), 'المحصّل − المصروفات',
              net >= 0 ? _green : _red),
          kpi('مقبوضات مسجلة بالشهر', _money(received, data.country),
              '${payments.length} دفعة', _navy),
        ]),
        sectionTitle('ملخص إيرادات الفواتير',
            subtitle: 'تفصيل مكوّنات فواتير ${_period(data.month)}'),
        table(
          headers: const ['البند', 'المبلغ', 'النسبة من المفوتر'],
          rows: [
            ['إيجار', _num(rent), _percent(rent, billed)],
            ['خدمات', _num(utilities), _percent(utilities, billed)],
            ['صيانة', _num(maintenance), _percent(maintenance, billed)],
            ['رسوم أخرى', _num(other), _percent(other, billed)],
            ['إجمالي المفوتر', _num(billed), '100%'],
          ],
          widths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
          },
          emphasizeLastRow: true,
          alignments: const {
            0: pw.Alignment.centerRight,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
          },
        ),
        sectionTitle('فواتير الشهر',
            subtitle:
                'التاريخ والاستحقاق بصيغة سنة/شهر/يوم · المبالغ بال${data.country.currencyAr}'),
        table(
          headers: const [
            '#',
            'رقم الفاتورة',
            'الإصدار',
            'الاستحقاق',
            'المستأجر',
            'الوحدة / العقار',
            'إيجار',
            'خدمات',
            'صيانة',
            'أخرى',
            'الإجمالي',
            'المدفوع',
            'المتبقي',
            'الحالة',
          ],
          widths: {
            0: const pw.FixedColumnWidth(20),
            1: const pw.FixedColumnWidth(62),
            2: const pw.FixedColumnWidth(44),
            3: const pw.FixedColumnWidth(44),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(3),
            6: const pw.FixedColumnWidth(42),
            7: const pw.FixedColumnWidth(36),
            8: const pw.FixedColumnWidth(36),
            9: const pw.FixedColumnWidth(36),
            10: const pw.FixedColumnWidth(48),
            11: const pw.FixedColumnWidth(46),
            12: const pw.FixedColumnWidth(46),
            13: const pw.FixedColumnWidth(52),
          },
          rows: [
            for (var i = 0; i < invoices.length; i++)
              [
                '${i + 1}',
                invoices[i].number,
                _date(invoices[i].invoiceDate),
                invoices[i].dueDate == null
                    ? '—'
                    : _date(invoices[i].dueDate!),
                invoices[i].tenantName ?? '—',
                [
                  invoices[i].apartmentLabel,
                  invoices[i].compoundName,
                ]
                    .where((value) => value != null && value.trim().isNotEmpty)
                    .join(' · '),
                _num(invoices[i].rentAmount),
                _num(invoices[i].utilitiesAmount),
                _num(invoices[i].maintenanceAmount),
                _num(invoices[i].otherCharges),
                _num(invoices[i].totalAmount),
                _num(invoices[i].paidAmount),
                _num(invoices[i].remaining),
                invoices[i].statusLabel,
              ],
            [
              '',
              'الإجمالي',
              '',
              '',
              '',
              '',
              _num(rent),
              _num(utilities),
              _num(maintenance),
              _num(other),
              _num(billed),
              _num(collected),
              _num(outstanding),
              '',
            ],
          ],
          alignments: const {
            0: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
            6: pw.Alignment.center,
            7: pw.Alignment.center,
            8: pw.Alignment.center,
            9: pw.Alignment.center,
            10: pw.Alignment.center,
            11: pw.Alignment.center,
            12: pw.Alignment.center,
            13: pw.Alignment.center,
          },
          statusColors: [for (final invoice in invoices) _statusColor(invoice)],
          emptyText: 'لا توجد فواتير لهذا الشهر',
        ),
        sectionTitle('المقبوضات المسجلة بالشهر',
            subtitle: 'الدفعات المسجلة عبر النظام خلال ${_period(data.month)}'),
        table(
          headers: const [
            '#',
            'التاريخ',
            'المستأجر',
            'المبلغ',
            'طريقة الدفع',
            'رقم الإيصال',
            'ملاحظات',
          ],
          widths: {
            0: const pw.FixedColumnWidth(20),
            1: const pw.FixedColumnWidth(58),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FixedColumnWidth(60),
            4: const pw.FixedColumnWidth(58),
            5: const pw.FixedColumnWidth(58),
            6: const pw.FlexColumnWidth(3),
          },
          rows: [
            for (var i = 0; i < payments.length; i++)
              [
                '${i + 1}',
                _date(payments[i].paymentDate),
                payments[i].tenantName ?? '—',
                _num(payments[i].amount),
                payments[i].methodLabel,
                payments[i].receiptNumber ?? '—',
                payments[i].notes ?? '',
              ],
            ['', 'الإجمالي', '', _num(received), '', '', ''],
          ],
          alignments: const {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.center,
          },
          emptyText: 'لا توجد مقبوضات مسجلة خلال هذا الشهر',
        ),
        sectionTitle('المصروفات',
            subtitle: 'المصروفات المسجلة على عقارات ${data.country.nameAr}'),
        table(
          headers: const [
            '#',
            'التاريخ',
            'التصنيف',
            'البيان',
            'العقار / المبنى',
            'المبلغ',
            'ملاحظات',
          ],
          widths: {
            0: const pw.FixedColumnWidth(20),
            1: const pw.FixedColumnWidth(58),
            2: const pw.FixedColumnWidth(58),
            3: const pw.FlexColumnWidth(3),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FixedColumnWidth(60),
            6: const pw.FlexColumnWidth(3),
          },
          rows: [
            for (var i = 0; i < expenses.length; i++)
              [
                '${i + 1}',
                _date(expenses[i].date),
                expenses[i].categoryLabel,
                expenses[i].title,
                expenses[i].scopeLabel,
                _num(expenses[i].amount),
                expenses[i].notes ?? '',
              ],
            ['', 'الإجمالي', '', '', '', _num(expensesTotal), ''],
          ],
          alignments: const {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            5: pw.Alignment.center,
          },
          emptyText: 'لا توجد مصروفات مسجلة خلال هذا الشهر',
        ),
        sectionTitle('التحليل حسب العقار',
            subtitle: 'مقارنة المفوتر والمحصّل والمصروفات وصافي كل عقار'),
        table(
          headers: const [
            'العقار',
            'فواتير',
            'مفوتر',
            'محصّل',
            'متبقي',
            'مصروفات',
            'صافي',
          ],
          widths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FixedColumnWidth(46),
            2: const pw.FixedColumnWidth(62),
            3: const pw.FixedColumnWidth(62),
            4: const pw.FixedColumnWidth(62),
            5: const pw.FixedColumnWidth(62),
            6: const pw.FixedColumnWidth(62),
          },
          rows: [
            for (final name in compounds)
              [
                name,
                '${(compoundRows[name]?[0] ?? 0).round()}',
                _num(compoundRows[name]?[1] ?? 0),
                _num(compoundRows[name]?[2] ?? 0),
                _num(compoundRows[name]?[3] ?? 0),
                _num(expenseByCompound[name] ?? 0),
                _num((compoundRows[name]?[2] ?? 0) -
                    (expenseByCompound[name] ?? 0)),
              ],
            if (compounds.isNotEmpty)
              [
                'الإجمالي',
                '${invoices.length}',
                _num(billed),
                _num(collected),
                _num(outstanding),
                _num(expensesTotal),
                _num(net),
              ],
          ],
          alignments: const {
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.center,
            6: pw.Alignment.center,
          },
          emptyText: 'لا توجد عقارات لها حركة مالية هذا الشهر',
        ),
        sectionTitle('ملاحظات محاسبية'),
        pw.Container(
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: _soft,
            border: pw.Border.all(color: _line, width: .4),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final note in [
                'جميع المبالغ في هذا التقرير بالعملة ${data.country.currencyAr} (${data.country.nameAr}).',
                'إجمالي المفوتر = الإيجار + الخدمات + الصيانة + الرسوم الأخرى لجميع فواتير الشهر.',
                'المحصّل = مجموع المبالغ المسددة والمثبتة على فواتير الشهر.',
                'المتبقي = إجمالي المفوتر − المحصّل، ويشمل الفواتير الجزئية والمتأخرة.',
                'المصروفات = إجمالي المصروفات المسجلة على العقارات خلال الشهر.',
                'صافي الشهر = المحصّل − المصروفات، ولا يحتسب الفواتير غير المحصلة.',
                'المقبوضات المسجلة بالشهر قد تشمل دفعات عن فواتير أشهر سابقة، وتُعرض للتدقيق النقدي.',
                'الفواتير المتأخرة = فواتير غير مسددة تجاوزت تاريخ استحقاقها بتاريخ إصدار التقرير.',
              ])
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4, left: 4),
                        width: 3,
                        height: 3,
                        decoration: const pw.BoxDecoration(
                          color: _gold,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          note,
                          style: pw.TextStyle(
                            font: regular,
                            fontSize: 7.3,
                            color: _ink,
                            lineSpacing: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            signature('إعداد / المحاسب'),
            pw.SizedBox(width: 10),
            signature('اعتماد / إدارة العقارات'),
            pw.SizedBox(width: 10),
            signature('الختم الرسمي'),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'أُصدر هذا التقرير آلياً بتاريخ ${_date(DateTime.now())} — نظام The City Property',
          style: pw.TextStyle(font: regular, fontSize: 6.5, color: _muted),
        ),
      ],
    ),
  );

  return document.save();
}

Future<void> downloadAccountingReportPdf(AccountingReportData data) async {
  final bytes = await buildAccountingReportPdf(data);
  final filename =
      'TheCityProperty-Accounting-${data.month.year}-${_two(data.month.month)}.pdf';
  await Printing.sharePdf(bytes: bytes, filename: filename);
}
