import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_city_property/core/i18n/app_country.dart';
import 'package:the_city_property/data/models.dart';
import 'package:the_city_property/features/owner/web/accounting_report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a detailed accounting report pdf', () async {
    final month = DateTime(2026, 11, 1);
    final invoices = [
      Invoice(
        id: 'inv-1',
        leaseId: 'lease-1',
        apartmentId: 'apt-1',
        tenantId: 'tenant-1',
        number: 'INV-202611-83a1c7',
        invoiceDate: month,
        dueDate: DateTime(2026, 11, 10),
        rentAmount: 500000,
        totalAmount: 500000,
        paidAmount: 0,
        status: 'pending',
        tenantName: 'محمد علي حسين الجبوري',
        apartmentLabel: 'شقة 42 · عمارة 13',
        compoundName: 'مجمع النخيل',
        country: AppCountry.iq,
      ),
      Invoice(
        id: 'inv-2',
        leaseId: 'lease-2',
        apartmentId: 'apt-2',
        tenantId: 'tenant-2',
        number: 'INV-202611-606f15',
        invoiceDate: month,
        dueDate: DateTime(2026, 11, 10),
        rentAmount: 800000,
        utilitiesAmount: 50000,
        totalAmount: 850000,
        paidAmount: 400000,
        status: 'partial',
        tenantName: 'علي حسون هاشم',
        apartmentLabel: 'شقة 7 · بناية A',
        compoundName: 'مجمع الياسمين',
        country: AppCountry.iq,
      ),
      Invoice(
        id: 'inv-3',
        leaseId: 'lease-3',
        apartmentId: 'apt-3',
        tenantId: 'tenant-3',
        number: 'INV-202611-71b2de',
        invoiceDate: month,
        dueDate: DateTime(2026, 11, 10),
        rentAmount: 1200000,
        maintenanceAmount: 25000,
        otherCharges: 10000,
        totalAmount: 1235000,
        paidAmount: 1235000,
        status: 'paid',
        tenantName: 'سارة كريم عبد الله',
        apartmentLabel: 'شقة 3 · بناية B',
        compoundName: 'مجمع النخيل',
        country: AppCountry.iq,
      ),
    ];

    final payments = [
      Payment(
        id: 'pay-1',
        tenantId: 'tenant-2',
        amount: 400000,
        paymentDate: DateTime(2026, 11, 5),
        paymentMethod: 'cash',
        notes: 'دفعة أولى',
        tenantName: 'علي حسون هاشم',
      ),
      Payment(
        id: 'pay-2',
        tenantId: 'tenant-3',
        amount: 1235000,
        paymentDate: DateTime(2026, 11, 8),
        paymentMethod: 'transfer',
        receiptNumber: 'RCP-1002',
        tenantName: 'سارة كريم عبد الله',
      ),
    ];

    final expenses = [
      Expense(
        id: 'exp-1',
        compoundId: 'c-1',
        category: 'maintenance',
        title: 'صيانة مضخة الماء',
        amount: 150000,
        date: DateTime(2026, 11, 3),
        compoundName: 'مجمع النخيل',
        country: AppCountry.iq,
      ),
      Expense(
        id: 'exp-2',
        compoundId: 'c-2',
        category: 'salaries',
        title: 'راتب حارس البناية',
        amount: 300000,
        date: DateTime(2026, 11, 4),
        compoundName: 'مجمع الياسمين',
        buildingName: 'بناية A',
        country: AppCountry.iq,
      ),
      Expense(
        id: 'exp-3',
        compoundId: 'c-1',
        category: 'cleaning',
        title: 'تنظيف الممرات',
        amount: 75000,
        date: DateTime(2026, 11, 9),
        compoundName: 'مجمع النخيل',
        country: AppCountry.iq,
      ),
      Expense(
        id: 'exp-4',
        compoundId: 'c-1',
        category: 'utilities',
        title: 'فاتورة كهرباء مشتركة',
        amount: 200000,
        date: DateTime(2026, 11, 12),
        compoundName: 'مجمع النخيل',
        country: AppCountry.iq,
      ),
    ];

    final bytes = await buildAccountingReportPdf(
      AccountingReportData(
        ownerName: 'ياسر الشمري',
        month: month,
        country: AppCountry.iq,
        invoices: invoices,
        expenses: expenses,
        payments: payments,
      ),
    );

    expect(bytes.length, greaterThan(15000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    Directory('build').createSync(recursive: true);
    File('build/report_preview.pdf').writeAsBytesSync(bytes);

    final empty = await buildAccountingReportPdf(
      AccountingReportData(
        ownerName: 'ياسر الشمري',
        month: DateTime(2027, 1, 1),
        country: AppCountry.iq,
        invoices: const [],
        expenses: const [],
        payments: const [],
      ),
    );
    expect(String.fromCharCodes(empty.take(4)), '%PDF');
  });
}
