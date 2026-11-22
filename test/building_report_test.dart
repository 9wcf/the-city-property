import 'package:flutter_test/flutter_test.dart';
import 'package:the_city_property/core/utils/building_report.dart';
import 'package:the_city_property/data/models.dart';

void main() {
  final month = DateTime(2026, 11);

  const apartmentOne = Apartment(
    id: 'apt-1',
    floorId: 'floor-1',
    buildingId: 'building-1',
    unitNumber: '101',
    rentAmount: 500000,
    status: ApartmentStatus.occupied,
  );
  const apartmentTwo = Apartment(
    id: 'apt-2',
    floorId: 'floor-1',
    buildingId: 'building-1',
    unitNumber: '102',
    rentAmount: 500000,
    status: ApartmentStatus.vacant,
  );
  const apartmentThree = Apartment(
    id: 'apt-3',
    floorId: 'floor-2',
    buildingId: 'building-2',
    unitNumber: '201',
    rentAmount: 700000,
    status: ApartmentStatus.occupied,
  );

  Portfolio portfolio() => const Portfolio([
        Compound(
          id: 'compound-1',
          name: 'مجمع النخيل',
          ownerId: 'owner-1',
          buildings: [
            Building(
              id: 'building-1',
              compoundId: 'compound-1',
              name: 'عمارة A',
              floors: [
                Floor(
                  id: 'floor-1',
                  buildingId: 'building-1',
                  floorNumber: 1,
                  apartments: [apartmentOne, apartmentTwo],
                ),
              ],
            ),
            Building(
              id: 'building-2',
              compoundId: 'compound-1',
              name: 'عمارة B',
              floors: [
                Floor(
                  id: 'floor-2',
                  buildingId: 'building-2',
                  floorNumber: 1,
                  apartments: [apartmentThree],
                ),
              ],
            ),
          ],
        ),
      ]);

  const tenantOne = AppProfile(
    id: 'tenant-1',
    fullName: 'مستأجر أول',
    phoneNumber: '07701112223',
    role: UserRole.tenant,
  );
  const tenantTwo = AppProfile(
    id: 'tenant-2',
    fullName: 'مستأجر ثانٍ',
    phoneNumber: '07701112224',
    role: UserRole.tenant,
  );

  test('aggregates rent, payments and expenses per building', () {
    final reports = buildBuildingReports(
      portfolio: portfolio(),
      tenants: [
        TenantRecord(
          profile: tenantOne,
          apartment: apartmentOne,
          lease: Lease(
            id: 'lease-1',
            apartmentId: 'apt-1',
            tenantId: 'tenant-1',
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2027, 1, 1),
            monthlyRent: 500000,
            status: 'active',
          ),
        ),
        const TenantRecord(
          profile: tenantTwo,
          apartment: apartmentThree,
        ),
      ],
      payments: [
        Payment(
          id: 'pay-1',
          tenantId: 'tenant-1',
          amount: 200000,
          paymentDate: DateTime(2026, 11, 5),
          paymentMethod: 'cash',
        ),
        Payment(
          id: 'pay-old',
          tenantId: 'tenant-1',
          amount: 100000,
          paymentDate: DateTime(2026, 10, 5),
          paymentMethod: 'cash',
        ),
        Payment(
          id: 'pay-2',
          tenantId: 'tenant-2',
          amount: 700000,
          paymentDate: DateTime(2026, 11, 7),
          paymentMethod: 'transfer',
        ),
      ],
      expenses: [
        Expense(
          id: 'expense-1',
          compoundId: 'compound-1',
          buildingId: 'building-1',
          category: 'maintenance',
          title: 'صيانة مصعد',
          amount: 150000,
          date: DateTime(2026, 11, 6),
        ),
        Expense(
          id: 'expense-general',
          compoundId: 'compound-1',
          category: 'general',
          title: 'أمن وحراسة',
          amount: 50000,
          date: DateTime(2026, 11, 3),
        ),
        Expense(
          id: 'expense-old',
          compoundId: 'compound-1',
          buildingId: 'building-2',
          category: 'maintenance',
          title: 'صيانة قديمة',
          amount: 90000,
          date: DateTime(2026, 10, 20),
        ),
      ],
      month: month,
    );

    expect(reports, hasLength(1));
    final compound = reports.single;
    expect(compound.buildings, hasLength(2));

    final buildingOne = compound.buildings.first;
    expect(buildingOne.name, 'عمارة A');
    expect(buildingOne.units, 2);
    expect(buildingOne.occupied, 1);
    expect(buildingOne.due, 500000);
    expect(buildingOne.collected, 200000);
    expect(buildingOne.expenses, 150000);
    expect(buildingOne.outstanding, 300000);
    expect(buildingOne.net, 50000);

    final buildingTwo = compound.buildings.last;
    expect(buildingTwo.name, 'عمارة B');
    expect(buildingTwo.due, 700000);
    expect(buildingTwo.collected, 700000);
    expect(buildingTwo.expenses, 0);
    expect(buildingTwo.net, 700000);

    expect(compound.generalExpenses, 50000);
    expect(compound.due, 1200000);
    expect(compound.collected, 900000);
    expect(compound.buildingExpenses, 150000);
    expect(compound.totalExpenses, 200000);
    expect(compound.outstanding, 300000);
    expect(compound.net, 700000);
    expect(compound.units, 3);
    expect(compound.occupied, 2);
  });

  test('falls back to apartment status when no tenants are linked', () {
    final reports = buildBuildingReports(
      portfolio: portfolio(),
      tenants: const [],
      payments: const [],
      expenses: const [],
      month: month,
    );

    final compound = reports.single;
    expect(compound.buildings.first.occupied, 1);
    expect(compound.buildings.first.due, 0);
    expect(compound.buildings.first.net, 0);
    expect(compound.buildings.last.occupied, 1);
  });

  test('unknown building on an expense is counted as general', () {
    final reports = buildBuildingReports(
      portfolio: portfolio(),
      tenants: const [],
      payments: const [],
      expenses: [
        Expense(
          id: 'expense-unknown',
          compoundId: 'compound-1',
          buildingId: 'deleted-building',
          category: 'maintenance',
          title: 'بناية محذوفة',
          amount: 40000,
          date: DateTime(2026, 11, 2),
        ),
      ],
      month: month,
    );

    final compound = reports.single;
    expect(compound.generalExpenses, 40000);
    expect(compound.buildingExpenses, 0);
    expect(compound.net, -40000);
  });
}
