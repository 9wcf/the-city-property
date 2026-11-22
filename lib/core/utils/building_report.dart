import '../../data/models.dart';

class BuildingReport {
  final String id;
  final String name;
  final String compoundId;
  final String compoundName;
  final int units;
  final int occupied;
  final double due;
  final double collected;
  final double expenses;

  const BuildingReport({
    required this.id,
    required this.name,
    required this.compoundId,
    required this.compoundName,
    required this.units,
    required this.occupied,
    required this.due,
    required this.collected,
    required this.expenses,
  });

  double get outstanding => due - collected;
  double get net => collected - expenses;
}

class CompoundReport {
  final String id;
  final String name;
  final List<BuildingReport> buildings;
  final double generalExpenses;

  const CompoundReport({
    required this.id,
    required this.name,
    required this.buildings,
    required this.generalExpenses,
  });

  double get due => buildings.fold(0, (sum, b) => sum + b.due);
  double get collected => buildings.fold(0, (sum, b) => sum + b.collected);
  double get buildingExpenses =>
      buildings.fold(0, (sum, b) => sum + b.expenses);
  double get totalExpenses => buildingExpenses + generalExpenses;
  double get net => collected - totalExpenses;
  double get outstanding => due - collected;
  int get units => buildings.fold(0, (sum, b) => sum + b.units);
  int get occupied => buildings.fold(0, (sum, b) => sum + b.occupied);
}

/// واردات الشهر = الدفعات المسجلة فعلياً، والمصاريف = المسجلة على البناية أو
/// على المجمع ككل، والصافي = الواردات ناقص المصاريف.
List<CompoundReport> buildBuildingReports({
  required Portfolio portfolio,
  required List<TenantRecord> tenants,
  required List<Payment> payments,
  required List<Expense> expenses,
  required DateTime month,
}) {
  bool inMonth(DateTime date) =>
      date.year == month.year && date.month == month.month;

  final tenantBuilding = <String, String>{};
  final dueByBuilding = <String, double>{};
  final occupiedByBuilding = <String, int>{};
  for (final tenant in tenants) {
    final buildingId = tenant.apartment.buildingId;
    if (buildingId == null || buildingId.isEmpty) continue;
    tenantBuilding[tenant.profile.id] = buildingId;
    final rent = tenant.lease?.monthlyRent ?? tenant.apartment.rentAmount;
    dueByBuilding[buildingId] = (dueByBuilding[buildingId] ?? 0) + rent;
    occupiedByBuilding[buildingId] = (occupiedByBuilding[buildingId] ?? 0) + 1;
  }

  final collectedByBuilding = <String, double>{};
  for (final payment in payments) {
    if (!inMonth(payment.paymentDate)) continue;
    final buildingId = tenantBuilding[payment.tenantId];
    if (buildingId == null) continue;
    collectedByBuilding[buildingId] =
        (collectedByBuilding[buildingId] ?? 0) + payment.amount;
  }

  final knownBuildings = <String>{
    for (final compound in portfolio.compounds)
      for (final building in compound.buildings) building.id,
  };
  final expensesByBuilding = <String, double>{};
  final generalByCompound = <String, double>{};
  for (final expense in expenses) {
    if (!inMonth(expense.date)) continue;
    final buildingId = expense.buildingId;
    if (buildingId != null && knownBuildings.contains(buildingId)) {
      expensesByBuilding[buildingId] =
          (expensesByBuilding[buildingId] ?? 0) + expense.amount;
    } else {
      generalByCompound[expense.compoundId] =
          (generalByCompound[expense.compoundId] ?? 0) + expense.amount;
    }
  }

  return [
    for (final compound in portfolio.compounds)
      CompoundReport(
        id: compound.id,
        name: compound.name,
        generalExpenses: generalByCompound[compound.id] ?? 0,
        buildings: [
          for (final building in compound.buildings)
            BuildingReport(
              id: building.id,
              name: building.name,
              compoundId: compound.id,
              compoundName: compound.name,
              units: building.apartments.length,
              occupied: occupiedByBuilding[building.id] ??
                  building.apartments
                      .where((a) => a.status == ApartmentStatus.occupied)
                      .length,
              due: dueByBuilding[building.id] ?? 0,
              collected: collectedByBuilding[building.id] ?? 0,
              expenses: expensesByBuilding[building.id] ?? 0,
            ),
        ],
      ),
  ];
}
