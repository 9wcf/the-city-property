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
import '../../core/i18n/i18n.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsProvider);
    await ref.read(notificationsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => 0,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإشعارات',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unread == 0
                          ? 'لا توجد إشعارات غير مقروءة'
                          : '$unread إشعار غير مقروء',
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('تعليم الكل كمقروء'),
                onPressed: unread == 0
                    ? null
                    : () async {
                        await ref
                            .read(repositoryProvider)
                            .markAllNotificationsRead();
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadNotificationsProvider);
                      },
                icon: const Icon(Icons.done_all_rounded,
                    color: AppColors.textSecondary),
              ),
              IconButton(
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: NotificationsFeed(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
            onChanged: () {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsProvider);
            },
          ),
        ),
      ],
    );
  }
}

class NotificationsFeed extends ConsumerWidget {
  const NotificationsFeed({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onChanged,
  });

  final EdgeInsets padding;
  final VoidCallback? onChanged;

  Future<void> _markRead(WidgetRef ref, AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await ref.read(repositoryProvider).markNotificationRead(notification.id);
      onChanged?.call();
    } catch (_) {
      // The feed still refreshes from the server on the next pull.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return async.when(
      loading: () => const LoadingList(count: 4),
      error: (error, _) => ErrorView(
        message: friendlyError(error),
        onRetry: () => ref.invalidate(notificationsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return ListView(
            padding: padding,
            children: const [
              GlassCard(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'لا توجد إشعارات بعد',
                  message:
                      'ستصلك هنا إشعارات البلاغات، الدفعات، الفواتير، وطلبات السكن.',
                ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadNotificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return _NotificationTile(
                notification: item,
                onTap: () => _markRead(ref, item),
              );
            },
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return GlassCard(
      onTap: onTap,
      borderColor: unread
          ? notification.color.withValues(alpha: .35)
          : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: notification.color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(notification.icon,
                color: notification.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: notification.color,
                        ),
                      ),
                    Text(
                      formatRelative(notification.createdAt),
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 9,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
