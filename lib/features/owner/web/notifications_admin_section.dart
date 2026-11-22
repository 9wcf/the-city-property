import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import '../../shared/notifications_screen.dart';
import 'web_ui.dart';

class NotificationsAdminSection extends ConsumerStatefulWidget {
  const NotificationsAdminSection({super.key});

  @override
  ConsumerState<NotificationsAdminSection> createState() =>
      _NotificationsAdminSectionState();
}

class _NotificationsAdminSectionState
    extends ConsumerState<NotificationsAdminSection> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'all';
  String? _compoundId;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsProvider);
    ref.invalidate(announcementsProvider);
    await ref.read(notificationsProvider.future);
  }

  Future<void> _send(List<Compound> compounds) async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final compoundId = _compoundId;
    if (title.length < 3) {
      setState(() => _error = 'أدخل عنواناً واضحاً للإشعار');
      return;
    }
    if (body.length < 3) {
      setState(() => _error = 'أدخل نص الإشعار');
      return;
    }
    if (compoundId == null) {
      setState(() => _error = 'اختر العقار المستهدف');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final recipients = await ref.read(repositoryProvider).broadcast(
            compoundId: compoundId,
            audience: _audience,
            title: title,
            body: body,
          );
      ref.invalidate(announcementsProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
      if (!mounted) return;
      setState(() {
        _title.clear();
        _body.clear();
        _sending = false;
      });
      showSuccess(
        context,
        recipients == 0
            ? 'لم يتم العثور على مستلمين مطابقين في هذا العقار'
            : 'تم إرسال الإشعار إلى $recipients مستخدماً',
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(ownerDashboardProvider);
    final announcements = ref.watch(announcementsProvider);
    final country = ref.watch(ownerCountryProvider);
    final inbox = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => 0,
        );

    return dashboard.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ErrorView(
          message: friendlyError(error),
          onRetry: () => ref.invalidate(ownerDashboardProvider),
        ),
      ),
      data: (data) {
        final compounds = data.snapshot.portfolio.compounds
            .where((compound) => compound.country == country)
            .toList();
        final sent = announcements.maybeWhen(
          data: (value) => value
              .where((announcement) => announcement.country == country)
              .toList(),
          orElse: () => const <Announcement>[],
        );
        final inboxItems = inbox.maybeWhen(
          data: (value) => value,
          orElse: () => const <AppNotification>[],
        );

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WebPageHeader(
                title: 'الإشعارات والتواصل',
                subtitle:
                    'أرسل إشعارات فورية للمستأجرين والمديرين في ${country.name(english: I18n.isEnglish)} داخل التطبيق وعلى هواتفهم',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('تحديث'),
                  ),
                  OutlinedButton.icon(
                    onPressed: unread == 0
                        ? null
                        : () async {
                            await ref
                                .read(repositoryProvider)
                                .markAllNotificationsRead();
                            await _refresh();
                          },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('تعليم الكل كمقروء'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebKpiGrid(
                children: [
                  WebKpiCard(
                    label: 'رسائل مرسلة',
                    value: '${sent.length}',
                    icon: Icons.campaign_rounded,
                    color: AppColors.gold,
                    caption: 'إعلانات العقارات',
                  ),
                  WebKpiCard(
                    label: 'إشعاراتك غير المقروءة',
                    value: '$unread',
                    icon: Icons.mark_email_unread_rounded,
                    color: unread == 0 ? AppColors.textMuted : AppColors.pending,
                  ),
                  WebKpiCard(
                    label: 'كل إشعاراتك',
                    value: '${inboxItems.length}',
                    icon: Icons.notifications_rounded,
                    color: AppColors.info,
                    caption: 'صندوق الوارد',
                  ),
                  WebKpiCard(
                    label: 'العقارات المتاحة',
                    value: '${compounds.length}',
                    icon: Icons.domain_rounded,
                    color: AppColors.reserved,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebColumns(
                firstFlex: 3,
                secondFlex: 2,
                first: WebPanel(
                  title: 'إرسال إشعار',
                  subtitle: 'يصل فوراً إلى صندوق إشعارات المستخدمين',
                  glowColor: AppColors.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: compounds
                                      .any((compound) => compound.id == _compoundId)
                                  ? _compoundId
                                  : null,
                              isExpanded: true,
                              dropdownColor: AppColors.navy800,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: tr('العقار'),
                                prefixIcon:
                                    Icon(Icons.location_city_rounded),
                              ),
                              items: compounds
                                  .map(
                                    (compound) => DropdownMenuItem(
                                      value: compound.id,
                                      child: Text(
                                        compound.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _sending
                                  ? null
                                  : (value) =>
                                      setState(() => _compoundId = value),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _audience,
                              isExpanded: true,
                              dropdownColor: AppColors.navy800,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: tr('الجمهور'),
                                prefixIcon: Icon(Icons.groups_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('الجميع (مستأجرون ومديرون)'),
                                ),
                                DropdownMenuItem(
                                  value: 'tenants',
                                  child: Text('المستأجرون فقط'),
                                ),
                                DropdownMenuItem(
                                  value: 'managers',
                                  child: Text('المديرون فقط'),
                                ),
                              ],
                              onChanged: _sending
                                  ? null
                                  : (value) => setState(
                                      () => _audience = value ?? _audience),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _title,
                        enabled: !_sending,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: tr('عنوان الإشعار'),
                          hintText: tr('مثال: صيانة المصعد يوم السبت'),
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _body,
                        enabled: !_sending,
                        maxLines: 5,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: tr('نص الإشعار'),
                          alignLabelWithHint: true,
                          hintText: tr('اكتب تفاصيل الإشعار الذي سيصل للمستأجرين والمديرين...'),
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            height: 1.5,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _sending ? null : () => _send(compounds),
                            icon: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.navy900,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: const Text('إرسال الآن'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: Text(
                              'سيصل الإشعار للمستأجرين المرتبطين بعقود نشطة والمديرين المعيّنين على العقار.',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                height: 1.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                second: Column(
                  children: [
                    const WebPanel(
                      title: 'قنوات الوصول',
                      subtitle: 'كيف يستلم المستخدم الإشعار',
                      child: Column(
                        children: [
                          _ChannelRow(
                            icon: Icons.notifications_active_rounded,
                            color: AppColors.occupied,
                            title: 'داخل التطبيق',
                            subtitle:
                                'تنبيه فوري في تبويب الإشعارات مع عدّاد غير مقروء.',
                          ),
                          SizedBox(height: 10),
                          _ChannelRow(
                            icon: Icons.sms_rounded,
                            color: AppColors.info,
                            title: 'إشعارات الهاتف',
                            subtitle:
                                'عبر Firebase FCM حتى والتطبيق مغلق، بعد ربط مفاتيح Firebase.',
                          ),
                          SizedBox(height: 10),
                          _ChannelRow(
                            icon: Icons.campaign_rounded,
                            color: AppColors.gold,
                            title: 'إعلان محفوظ',
                            subtitle:
                                'يُحفظ النص في سجل الإعلانات لمراجعة ما أُرسل ومتى.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    WebPanel(
                      title: 'صندوق واردك',
                      subtitle: unread == 0
                          ? 'لا إشعارات غير مقروءة'
                          : '$unread إشعار غير مقروء',
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm, AppSpacing.md, AppSpacing.sm, 0),
                      child: SizedBox(
                        height: 420,
                        child: NotificationsFeed(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.md),
                          onChanged: () {
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadNotificationsProvider);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              WebPanel(
                title: 'الإعلانات المرسلة',
                subtitle: 'سجل الرسائل الجماعية لعقاراتك',
                child: announcements.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.gold),
                    ),
                  ),
                  error: (error, _) => WebEmpty(
                    icon: Icons.cloud_off_rounded,
                    title: 'تعذّر تحميل السجل',
                    message: friendlyError(error),
                  ),
                  data: (items) => WebTable(
                    empty: const WebEmpty(
                      icon: Icons.campaign_outlined,
                      title: 'لم ترسل أي إشعار جماعي بعد',
                      message:
                          'اكتب رسالتك أعلاه واختر الجمهور ثم اضغط «إرسال الآن».',
                    ),
                    columns: const [
                      WebTableColumn('العنوان', flex: 3),
                      WebTableColumn('النص', flex: 4),
                      WebTableColumn('العقار', flex: 2),
                      WebTableColumn('التاريخ', flex: 2),
                    ],
                    rows: items
                        .map(
                          (item) => [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              item.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              item.compoundName ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              item.publishedAt == null
                                  ? '—'
                                  : formatRelative(item.publishedAt!),
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 9,
                    height: 1.5,
                    color: AppColors.textMuted,
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
