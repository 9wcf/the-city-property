import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../shared/request_card.dart';
import '../shared/request_detail_screen.dart';

class ManagerRequestsScreen extends ConsumerStatefulWidget {
  const ManagerRequestsScreen({super.key, required this.profile});

  final AppProfile profile;

  @override
  ConsumerState<ManagerRequestsScreen> createState() => _ManagerRequestsScreenState();
}

class _ManagerRequestsScreenState extends ConsumerState<ManagerRequestsScreen> {
  String _filter = 'نشطة';

  Future<void> _refresh() async {
    ref.invalidate(managerSnapshotProvider);
    await ref.read(managerSnapshotProvider.future);
  }

  List<MaintenanceRequest> _apply(List<MaintenanceRequest> requests) {
    switch (_filter) {
      case 'نشطة':
        return requests.where((r) => r.isOpen).toList();
      case 'بانتظار المالك':
        return requests.where((r) => r.needsOwnerApproval).toList();
      case 'جاهزة للتنفيذ':
        return requests.where((r) => r.isApproved && !r.isCompleted).toList();
      case 'مكتملة':
        return requests.where((r) => r.isCompleted).toList();
      default:
        return requests;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(managerSnapshotProvider);
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
                      'طلبات الصيانة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'تابع الطلبات من الاستلام حتى الإكمال',
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
            filters: const ['نشطة', 'بانتظار المالك', 'جاهزة للتنفيذ', 'مكتملة', 'الكل'],
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
        ),
        Expanded(
          child: snapshotAsync.when(
            loading: () => const LoadingList(count: 4),
            error: (error, _) => ErrorView(message: friendlyError(error), onRetry: _refresh),
            data: (snapshot) {
              final requests = _apply(snapshot.requests);
              if (requests.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: const [
                    GlassCard(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: EmptyState(
                        icon: Icons.build_circle_outlined,
                        title: 'لا توجد طلبات في هذا التصنيف',
                        message: 'اختر تصنيفاً آخر أو اسحب للأسفل للتحديث.',
                      ),
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                color: AppColors.gold,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _MiniStat(label: 'نشطة', value: '${snapshot.activeRequests.length}', color: AppColors.info)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _MiniStat(label: 'عاجلة', value: '${snapshot.urgentCount}', color: AppColors.danger)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _MiniStat(label: 'بانتظار المالك', value: '${snapshot.awaitingApproval.length}', color: AppColors.gold)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _MiniStat(label: 'جاهزة', value: '${snapshot.readyToExecute.length}', color: AppColors.occupied)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...requests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: RequestCard(
                          request: request,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RequestDetailScreen(requestId: request.id, viewer: widget.profile),
                              ),
                            );
                            ref.invalidate(managerSnapshotProvider);
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 17, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 8, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
