import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/i18n/app_country.dart';
import '../core/i18n/i18n.dart';
import '../core/services/app_prefs.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../data/repositories.dart';

class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController() : super(I18n.language);

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    I18n.setLanguage(language);
    intl.Intl.defaultLocale = language.name;
    state = language;
    await AppPrefs.saveLanguage(language);
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>(
        (ref) => AppLanguageController());

/// Country currently in focus on the owner dashboard (currency + filtering).
final ownerCountryProvider =
    StateProvider<AppCountry>((ref) => AppCountry.iq);

/// Whether the owner is inside a country workspace (vs. the country picker).
/// Kept in a provider so it survives the full rebuild on language change.
final ownerCountryEnteredProvider = StateProvider<bool>((ref) => false);

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final repositoryProvider = Provider<SupabaseRepository>((ref) {
  return SupabaseRepository(ref.watch(supabaseProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

final sessionControllerProvider = ChangeNotifierProvider<SessionController>((ref) {
  return SessionController(ref.watch(authServiceProvider));
});

final currentProfileProvider = FutureProvider<AppProfile?>((ref) async {
  final session = ref.watch(sessionControllerProvider).session;
  if (session == null) return null;

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  return ref.watch(repositoryProvider).resolveProfile(user);
});

final ownerSnapshotProvider = FutureProvider<OwnerSnapshot>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) throw Exception('الجلسة منتهية');
  return ref.watch(repositoryProvider).ownerSnapshot(profile);
});

final managerSnapshotProvider = FutureProvider<ManagerSnapshot>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) throw Exception('الجلسة منتهية');
  return ref.watch(repositoryProvider).managerSnapshot(profile);
});

final tenantSnapshotProvider = FutureProvider<TenantSnapshot>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) throw Exception('الجلسة منتهية');
  return ref.watch(repositoryProvider).tenantSnapshot(profile);
});

class OwnerDashboardData {
  final OwnerSnapshot snapshot;
  final List<MemberRow> members;
  final List<Invoice> invoices;
  final List<Expense> expenses;

  const OwnerDashboardData({
    required this.snapshot,
    required this.members,
    required this.invoices,
    required this.expenses,
  });

  List<MemberRow> get managers =>
      members.where((m) => m.role == UserRole.manager).toList();

  List<MemberRow> get tenants =>
      members.where((m) => m.role == UserRole.tenant).toList();

  double get totalBilled => invoices.fold(0, (sum, i) => sum + i.totalAmount);
  double get totalCollected => invoices.fold(0, (sum, i) => sum + i.paidAmount);
  double get totalOutstanding => invoices.fold(0, (sum, i) => sum + i.remaining);
  double get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
  double get netIncome => totalCollected - totalExpenses;
  int get overdueInvoices => invoices.where((i) => i.isOverdue).length;
}

final ownerDashboardProvider = FutureProvider<OwnerDashboardData>((ref) async {
  final snapshot = await ref.watch(ownerSnapshotProvider.future);
  final repo = ref.watch(repositoryProvider);
  final membersFuture = repo.ownerMembers();
  final invoicesFuture = repo.invoices();
  final expensesFuture = repo.expenses();
  return OwnerDashboardData(
    snapshot: snapshot,
    members: await membersFuture,
    invoices: await invoicesFuture,
    expenses: await expensesFuture,
  );
});

class ManagerAccountingData {
  final ManagerSnapshot snapshot;
  final List<Invoice> invoices;
  final List<Expense> expenses;

  const ManagerAccountingData({
    required this.snapshot,
    required this.invoices,
    required this.expenses,
  });
}

final managerAccountingProvider = FutureProvider<ManagerAccountingData>((ref) async {
  final snapshot = await ref.watch(managerSnapshotProvider.future);
  final repo = ref.watch(repositoryProvider);
  final invoicesFuture = repo.invoices();
  final expensesFuture = repo.expenses();
  final apartmentIds =
      snapshot.portfolio.apartments.map((apartment) => apartment.id).toSet();
  final compoundIds =
      snapshot.portfolio.compounds.map((compound) => compound.id).toSet();
  return ManagerAccountingData(
    snapshot: snapshot,
    invoices: (await invoicesFuture)
        .where((invoice) => apartmentIds.contains(invoice.apartmentId))
        .toList(),
    expenses: (await expensesFuture)
        .where((expense) => compoundIds.contains(expense.compoundId))
        .toList(),
  );
});

final apartmentManagersProvider =
    FutureProvider<List<ApartmentManagerAssignment>>((ref) {
  return ref.watch(repositoryProvider).apartmentManagers();
});

final compoundManagersProvider =
    FutureProvider<List<CompoundManagerAssignment>>((ref) {
  return ref.watch(repositoryProvider).compoundManagerAssignments();
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const [];
  return ref.watch(repositoryProvider).notifications();
});

final announcementsProvider = FutureProvider<List<Announcement>>((ref) {
  return ref.watch(repositoryProvider).ownerAnnouncements();
});

final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return 0;
  return ref.watch(repositoryProvider).unreadNotificationCount();
});

final vacantPortfolioProvider = FutureProvider<Portfolio>((ref) {
  return ref.watch(repositoryProvider).allVacantPortfolio();
});

final requestProvider = FutureProvider.autoDispose.family<MaintenanceRequest?, String>((ref, id) {
  return ref.watch(repositoryProvider).requestById(id);
});

final requestMessagesProvider =
    FutureProvider.autoDispose.family<List<MaintenanceMessage>, String>((ref, requestId) {
  return ref.watch(repositoryProvider).messagesForRequest(requestId);
});
