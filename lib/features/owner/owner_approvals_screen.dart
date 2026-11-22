import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/request_card.dart';
import '../shared/request_detail_screen.dart';

class OwnerApprovalsScreen extends ConsumerStatefulWidget {
  const OwnerApprovalsScreen({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<OwnerApprovalsScreen> createState() => _OwnerApprovalsScreenState();
}

class _OwnerApprovalsScreenState extends ConsumerState<OwnerApprovalsScreen> {
  String _filter = 'بانتظار الموافقة';

  Future<void> _refresh() async {
    ref.invalidate(ownerSnapshotProvider);
    await ref.read(ownerSnapshotProvider.future);
  }

  List<MaintenanceRequest> _apply(List<MaintenanceRequest> requests) {
    switch (_filter) {
      case 'بانتظار الموافقة':
        return requests.where((r) => r.needsOwnerApproval).toList();
      case 'موافق عليها':
        return requests.where((r) => r.isApproved).toList();
      case 'مرفوضة':
        return requests.where((r) => r.isRejected).toList();
      default:
        return requests;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(ownerSnapshotProvider);
    final country = ref.watch(ownerCountryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموافقات',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'راجع كلفة الصيانة قبل بدء التنفيذ',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: RequestFilterChips(
            filters: const ['بانتظار الموافقة', 'موافق عليها', 'مرفوضة', 'الكل'],
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
        ),
        Expanded(
          child: snapshotAsync.when(
            loading: () => const LoadingList(count: 4),
            error: (error, _) => ErrorView(message: friendlyError(error), onRetry: _refresh),
            data: (snapshot) {
              final apartmentIds = snapshot.portfolio.apartments
                  .where((apartment) => apartment.country == country)
                  .map((apartment) => apartment.id)
                  .toSet();
              final countryRequests = snapshot.requests
                  .where((request) => apartmentIds.contains(request.apartmentId))
                  .toList();
              final requests = _apply(countryRequests);
              if (requests.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: EmptyState(
                        icon: _filter == 'بانتظار الموافقة'
                            ? Icons.task_alt_rounded
                            : Icons.filter_alt_off_rounded,
                        title: _filter == 'بانتظار الموافقة' ? 'لا توجد موافقات معلقة' : 'لا توجد طلبات في هذا التصنيف',
                        message: _filter == 'بانتظار الموافقة'
                            ? 'عندما يحدد المدير كلفة طلب صيانة سيظهر هنا للموافقة.'
                            : 'جرّب اختيار تصنيف آخر.',
                      ),
                    ),
                  ],
                );
              }
              final pendingApprovals = countryRequests
                  .where((request) => request.needsOwnerApproval)
                  .toList();
              final pendingTotal = pendingApprovals.fold<double>(
                  0, (sum, request) => sum + (request.estimatedCost ?? 0));
              return RefreshIndicator(
                color: AppColors.gold,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
                  children: [
                    if (_filter == 'بانتظار الموافقة')
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: GlassCard(
                          glowColor: AppColors.gold,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 20),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'إجمالي الكلفة المعلقة',
                                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppColors.textMuted),
                                    ),
                                    Text(
                                      formatMoney(pendingTotal,
                                          withCurrency: true,
                                          country: country),
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                label: '${pendingApprovals.length} طلب',
                                color: AppColors.pending,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ...requests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: RequestCard(
                          request: request,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RequestDetailScreen(
                                  requestId: request.id,
                                  viewer: widget.profile,
                                ),
                              ),
                            );
                            ref.invalidate(ownerSnapshotProvider);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
