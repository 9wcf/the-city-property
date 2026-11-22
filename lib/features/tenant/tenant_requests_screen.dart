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

class TenantRequestsScreen extends ConsumerStatefulWidget {
  const TenantRequestsScreen({
    super.key,
    required this.profile,
    required this.onNewRequest,
  });

  final AppProfile profile;
  final VoidCallback onNewRequest;

  @override
  ConsumerState<TenantRequestsScreen> createState() => _TenantRequestsScreenState();
}

class _TenantRequestsScreenState extends ConsumerState<TenantRequestsScreen> {
  String _filter = 'الكل';

  List<MaintenanceRequest> _apply(List<MaintenanceRequest> requests) {
    switch (_filter) {
      case 'مفتوحة':
        return requests.where((r) => r.isOpen).toList();
      case 'مكتملة':
        return requests.where((r) => r.isCompleted).toList();
      case 'ملغاة':
        return requests.where((r) => r.status == 'cancelled').toList();
      default:
        return requests;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(tenantSnapshotProvider);
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
                      'طلباتي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'تابع كل طلبات الصيانة والخدمات',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onNewRequest,
                icon: const Icon(Icons.add_circle_rounded, color: AppColors.gold, size: 28),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: RequestFilterChips(
            filters: const ['الكل', 'مفتوحة', 'مكتملة', 'ملغاة'],
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
        ),
        Expanded(
          child: snapshotAsync.when(
            loading: () => const LoadingList(count: 3),
            error: (error, _) => ErrorView(
              message: friendlyError(error),
              onRetry: () => ref.invalidate(tenantSnapshotProvider),
            ),
            data: (snapshot) {
              final requests = _apply(snapshot.requests);
              if (requests.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: EmptyState(
                        icon: Icons.handyman_outlined,
                        title: 'لا توجد طلبات',
                        message: 'أرسل طلب صيانة أو خدمة وسيتم إشعار المدير فوراً.',
                        actionLabel: 'طلب جديد',
                        onAction: widget.onNewRequest,
                      ),
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async {
                  ref.invalidate(tenantSnapshotProvider);
                  await ref.read(tenantSnapshotProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 100),
                  children: requests.map((request) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RequestCard(
                        request: request,
                        showTenant: false,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RequestDetailScreen(
                                requestId: request.id,
                                viewer: widget.profile,
                                contact: snapshot.manager,
                              ),
                            ),
                          );
                          ref.invalidate(tenantSnapshotProvider);
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
