import '../../data/models.dart';
import '../i18n/app_country.dart';

/// The owner sees every compound; money must never mix currencies, so the
/// mobile screens narrow the snapshot to one country before showing totals.
class OwnerCountryView {
  const OwnerCountryView({
    required this.portfolio,
    required this.payments,
    required this.tenants,
    required this.requests,
  });

  factory OwnerCountryView.fromSnapshot(
    OwnerSnapshot snapshot,
    AppCountry country,
  ) {
    final portfolio = Portfolio(
      snapshot.portfolio.compounds
          .where((compound) => compound.country == country)
          .toList(),
    );
    final tenants = snapshot.tenants
        .where((tenant) => tenant.apartment.country == country)
        .toList();
    final tenantIds = tenants.map((tenant) => tenant.profile.id).toSet();
    final payments = snapshot.payments
        .where((payment) => tenantIds.contains(payment.tenantId))
        .toList();
    final apartmentIds = portfolio.apartmentIds.toSet();
    final requests = snapshot.requests
        .where((request) => apartmentIds.contains(request.apartmentId))
        .toList();
    return OwnerCountryView(
      portfolio: portfolio,
      payments: payments,
      tenants: tenants,
      requests: requests,
    );
  }

  final Portfolio portfolio;
  final List<Payment> payments;
  final List<TenantRecord> tenants;
  final List<MaintenanceRequest> requests;

  List<MaintenanceRequest> get pendingApprovals =>
      requests.where((request) => request.needsOwnerApproval).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));

  double get collectedThisMonth {
    final now = DateTime.now();
    return payments
        .where((payment) =>
            payment.paymentDate.year == now.year &&
            payment.paymentDate.month == now.month)
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  double get collectionRate {
    final expected = portfolio.monthlyExpected;
    return expected == 0 ? 0 : (collectedThisMonth / expected).clamp(0, 1);
  }

  int get overdueTenants {
    var count = 0;
    for (final tenant in tenants) {
      final lease = tenant.lease;
      if (lease == null || !lease.isActive) continue;
      if (tenant.paidThisMonth <= 0 &&
          nextDueDate(lease).isBefore(DateTime.now())) {
        count++;
      }
    }
    return count;
  }
}
