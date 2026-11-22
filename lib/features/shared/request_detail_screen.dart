import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/system_insets.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';
import '../../core/i18n/app_country.dart';
import '../../core/i18n/i18n.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.requestId,
    required this.viewer,
    this.contact,
  });

  final String requestId;
  final AppProfile viewer;
  final AppProfile? contact;

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final _messageController = TextEditingController();

  MaintenanceRequest? _request;
  List<MaintenanceMessage> _messages = const [];
  AppProfile? _tenant;
  AppProfile? _manager;
  AppCountry _country = defaultDisplayCountry;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final request = await repo.requestById(widget.requestId);
      if (request == null) throw Exception('لم يتم العثور على الطلب');
      final messages = await repo.messagesForRequest(request.id);
      final tenant = await repo.profileById(request.tenantId);
      AppProfile? manager;
      final apartment = await repo.apartmentById(request.apartmentId);
      if (apartment != null) {
        manager = await repo.managerForApartment(
          apartment.id,
          compoundId: apartment.compoundId,
        );
      }
      if (!mounted) return;
      setState(() {
        _request = request;
        _messages = messages;
        _tenant = tenant;
        _manager = manager;
        _country = apartment?.country ?? defaultDisplayCountry;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _loading = false;
      });
    }
  }

  void _invalidate() {
    ref.invalidate(requestProvider(widget.requestId));
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(managerSnapshotProvider);
    ref.invalidate(tenantSnapshotProvider);
  }

  AppProfile? get _counterpart {
    switch (widget.viewer.role) {
      case UserRole.tenant:
        return _manager ?? widget.contact;
      case UserRole.owner:
        return _manager ?? _tenant;
      case UserRole.manager:
        return _tenant;
    }
  }

  bool get _isManager => widget.viewer.role == UserRole.manager;
  bool get _isOwner => widget.viewer.role == UserRole.owner;
  bool get _isTenant => widget.viewer.role == UserRole.tenant;

  bool get _canSetEstimate =>
      _isManager && _request != null && !_request!.isCompleted && _request!.estimatedCost == null;

  bool get _canStart =>
      _isManager &&
      _request != null &&
      _request!.isApproved &&
      (_request!.status == 'submitted' ||
          _request!.status == 'pending' ||
          _request!.status == 'approved');

  bool get _canComplete =>
      _isManager && _request != null && _request!.isApproved && _request!.isInProgress;

  bool get _canDecide => _isOwner && (_request?.needsOwnerApproval ?? false);

  bool get _canCancel =>
      _isTenant &&
      _request != null &&
      (_request!.status == 'submitted' || _request!.status == 'pending');

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'تفاصيل الطلب',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
        ),
      ],
      body: _loading
          ? const LoadingList(count: 4)
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildContent(_request!),
    );
  }

  Widget _buildContent(MaintenanceRequest request) {
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          _buildHero(request),
          const SizedBox(height: AppSpacing.md),
          _buildActions(request),
          const SizedBox(height: AppSpacing.md),
          _buildDescription(request),
          if (request.imageUrls.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildPhotos(request),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildApproval(request),
          const SizedBox(height: AppSpacing.md),
          _buildTimeline(request),
          if (_counterpart != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildContact(request),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildChat(),
        ],
      ),
    );
  }

  Color _statusColor(MaintenanceRequest request) {
    if (request.isCompleted) return AppColors.occupied;
    if (request.isRejected) return AppColors.danger;
    if (request.isInProgress) return AppColors.info;
    if (request.needsOwnerApproval) return AppColors.gold;
    return AppColors.pending;
  }

  Widget _buildHero(MaintenanceRequest request) {
    final color = _statusColor(request);
    return GlassCard(
      glowColor: color,
      borderColor: color.withValues(alpha: .28),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: color.withValues(alpha: .28)),
                ),
                child: Icon(
                  maintenanceCategoryIcons[request.category] ?? Icons.handyman_rounded,
                  color: color,
                  size: 25,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [request.categoryLabel, request.apartmentLabel ?? '', formatRelative(request.createdAt)]
                          .where((e) => e.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusPill(
                label: request.statusLabel,
                color: color,
                icon: request.isCompleted
                    ? Icons.check_circle_rounded
                    : request.isInProgress
                        ? Icons.engineering_rounded
                        : Icons.schedule_rounded,
                compact: true,
              ),
              StatusPill(
                label: 'أولوية ${request.priorityLabel}',
                color: request.priority == 'emergency' || request.priority == 'urgent'
                    ? AppColors.danger
                    : request.priority == 'high'
                        ? AppColors.pending
                        : AppColors.textSecondary,
                icon: Icons.flag_rounded,
                compact: true,
              ),
              StatusPill(
                label: request.approvalLabel,
                color: request.isApproved
                    ? AppColors.occupied
                    : request.isRejected
                        ? AppColors.danger
                        : AppColors.gold,
                icon: Icons.verified_user_rounded,
                compact: true,
              ),
            ],
          ),
          if (request.tenantName != null && !_isTenant) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'مقدم الطلب: ${request.tenantName}',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(MaintenanceRequest request) {
    final buttons = <Widget>[];
    if (_canDecide) {
      buttons.add(
        Row(
          children: [
            Expanded(
              child: GoldButton(
                label: 'موافقة على الكلفة',
                icon: Icons.verified_rounded,
                loading: _busy,
                height: 50,
                onPressed: () => _decide(request, true),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SoftButton(
                label: 'رفض',
                icon: Icons.block_rounded,
                color: AppColors.danger,
                height: 50,
                onPressed: _busy ? null : () => _decide(request, false),
              ),
            ),
          ],
        ),
      );
    }
    if (_canSetEstimate) {
      buttons.add(
        GoldButton(
          label: 'تحديد الكلفة التقديرية',
          icon: Icons.request_quote_rounded,
          loading: _busy,
          onPressed: _setEstimate,
        ),
      );
    }
    if (_canStart) {
      buttons.add(
        GoldButton(
          label: 'بدء تنفيذ الأعمال',
          icon: Icons.handyman_rounded,
          loading: _busy,
          onPressed: _startWork,
        ),
      );
    }
    if (_canComplete) {
      buttons.add(
        GoldButton(
          label: 'إكمال الطلب وتسجيل الكلفة',
          icon: Icons.task_alt_rounded,
          loading: _busy,
          onPressed: _completeWork,
        ),
      );
    }
    if (_canCancel) {
      buttons.add(
        SoftButton(
          label: 'إلغاء الطلب',
          icon: Icons.close_rounded,
          color: AppColors.danger,
          onPressed: _busy ? null : _cancel,
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          buttons[i],
        ],
      ],
    );
  }

  Widget _buildDescription(MaintenanceRequest request) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'وصف المشكلة', subtitle: 'التفاصيل المرسلة من المستأجر'),
          const SizedBox(height: AppSpacing.md),
          Text(
            request.description.isEmpty ? 'لم يتم إضافة وصف.' : request.description,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
          ),
          if (request.managerNotes != null && request.managerNotes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.info.withValues(alpha: .22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.engineering_rounded, size: 15, color: AppColors.info),
                      SizedBox(width: 6),
                      Text(
                        'ملاحظات المدير',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.managerNotes!,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, height: 1.6, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotos(MaintenanceRequest request) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'الصور المرفقة',
            subtitle: '${request.imageUrls.length} صورة',
          ),
          const SizedBox(height: AppSpacing.md),
          PhotoGrid(urls: request.imageUrls, height: 120),
        ],
      ),
    );
  }

  Widget _buildApproval(MaintenanceRequest request) {
    final hasData = request.estimatedCost != null || request.finalCost != null || request.isRejected;
    if (!hasData) return const SizedBox.shrink();
    final approvedColor = request.isRejected ? AppColors.danger : AppColors.occupied;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'الكلفة والموافقة',
            subtitle: _isTenant
                ? 'حالة طلبك والكلفة'
                : 'شفافية كاملة بين المدير والمالك',
          ),
          const SizedBox(height: AppSpacing.md),
          if (request.estimatedCost != null)
            InfoRow(
              icon: Icons.request_quote_rounded,
              label: 'الكلفة التقديرية',
              value: formatMoney(request.estimatedCost!, withCurrency: true, country: _country),
              valueColor: AppColors.gold,
            ),
          if (request.finalCost != null)
            InfoRow(
              icon: Icons.payments_rounded,
              label: 'الكلفة النهائية',
              value: formatMoney(request.finalCost!, withCurrency: true, country: _country),
              valueColor: AppColors.occupied,
            ),
          InfoRow(
            icon: Icons.verified_user_rounded,
            label: _isTenant ? 'حالة الموافقة' : 'قرار المالك',
            value: request.approvalLabel,
            valueColor: request.isRejected
                ? AppColors.danger
                : request.isApproved
                    ? AppColors.occupied
                    : AppColors.gold,
          ),
          if (request.approvedAt != null)
            InfoRow(
              icon: Icons.event_available_rounded,
              label: 'تاريخ القرار',
              value: '${formatDate(request.approvedAt)} · ${formatTime(request.approvedAt)}',
            ),
          if (request.isRejected && request.rejectionReason != null)
            InfoRow(
              icon: Icons.info_outline_rounded,
              label: 'سبب الرفض',
              value: request.rejectionReason!,
              valueColor: AppColors.danger,
            ),
          if (request.needsOwnerApproval)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.gold.withValues(alpha: .25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isTenant
                          ? 'لا يبدأ العمل إلا بعد اعتماد الكلفة.'
                          : 'لا يبدأ العمل إلا بعد موافقة المالك على الكلفة.',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (request.isApproved && !request.isCompleted)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: approvedColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: approvedColor.withValues(alpha: .25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: approvedColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تمت الموافقة — يمكن للمدير البدء بالتنفيذ.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: approvedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline(MaintenanceRequest request) {
    final steps = <Widget>[
      TimelineStep(
        title: 'تم إنشاء الطلب',
        subtitle: request.createdAt == null
            ? '—'
            : '${formatDate(request.createdAt)} · ${formatTime(request.createdAt)}',
        icon: Icons.note_add_rounded,
        color: AppColors.info,
        isLast: false,
      ),
      TimelineStep(
        title: 'تحديد الكلفة التقديرية',
        subtitle: request.estimatedCost == null
            ? 'بانتظار المدير'
            : '${formatMoney(request.estimatedCost!, withCurrency: true, country: _country)} · ${formatRelative(request.updatedAt)}',
        icon: Icons.request_quote_rounded,
        color: AppColors.gold,
        isActive: request.estimatedCost != null,
        isLast: false,
      ),
      TimelineStep(
        title: _isTenant
            ? (request.isRejected ? 'رفض الكلفة' : 'اعتماد الكلفة')
            : (request.isRejected ? 'رفض المالك' : 'موافقة المالك'),
        subtitle: request.isRejected
            ? (request.rejectionReason ?? 'تم رفض الطلب')
            : request.approvedAt == null
                ? (_isTenant ? 'بانتظار الاعتماد' : 'بانتظار قرار المالك')
                : formatDate(request.approvedAt),
        icon: request.isRejected ? Icons.block_rounded : Icons.verified_user_rounded,
        color: request.isRejected ? AppColors.danger : AppColors.occupied,
        isActive: request.approvedAt != null,
        isLast: false,
      ),
      TimelineStep(
        title: 'بدء التنفيذ',
        subtitle: request.startedAt == null ? 'لم يبدأ بعد' : formatDate(request.startedAt),
        icon: Icons.handyman_rounded,
        color: AppColors.info,
        isActive: request.startedAt != null,
        isLast: false,
      ),
      TimelineStep(
        title: 'إكمال الطلب',
        subtitle: request.completedAt == null ? 'لم يكتمل بعد' : formatDate(request.completedAt),
        icon: Icons.task_alt_rounded,
        color: AppColors.occupied,
        isActive: request.completedAt != null,
        isLast: true,
      ),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'مسار الطلب', subtitle: 'متابعة كل مرحلة'),
          const SizedBox(height: AppSpacing.md),
          ...steps,
        ],
      ),
    );
  }

  Widget _buildContact(MaintenanceRequest request) {
    final person = _counterpart!;
    final label = switch (widget.viewer.role) {
      UserRole.tenant => 'مدير العقارات',
      UserRole.owner => _manager != null ? 'مدير العقارات' : 'المستأجر',
      UserRole.manager => 'المستأجر',
    };
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'التواصل المباشر', subtitle: label),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppAvatar(name: person.displayName, imageUrl: person.avatarUrl, size: 46),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      prettyPhone(person.phoneNumber),
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          contactActions(
            context: context,
            phone: person.phoneNumber,
            message: 'بخصوص طلب الصيانة: ${request.title}',
            color: _statusColor(request),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    final mine = widget.viewer.id;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المحادثة', subtitle: 'سجل التواصل حول الطلب'),
          const SizedBox(height: AppSpacing.md),
          if (_messages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'لا توجد رسائل بعد. ابدأ المحادثة لتوثيق كل التفاصيل.',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, height: 1.6, color: AppColors.textMuted),
              ),
            )
          else
            ..._messages.map((message) {
              final isMine = message.senderId == mine;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Align(
                  alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: isMine
                          ? AppColors.gold.withValues(alpha: .14)
                          : Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isMine ? 14 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 14),
                      ),
                      border: Border.all(
                        color: isMine
                            ? AppColors.gold.withValues(alpha: .35)
                            : Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.senderName != null)
                          Text(
                            message.senderName!,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isMine ? AppColors.gold : AppColors.textMuted,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          message.body,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${formatDate(message.createdAt)} · ${formatTime(message.createdAt)}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 8, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: tr('اكتب رسالة…'),
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 46,
                height: 46,
                child: Material(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _busy ? null : _sendMessage,
                    child: const Icon(Icons.send_rounded, size: 20, color: AppColors.navy900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ actions

  Future<void> _setEstimate() async {
    final result = await _showCostSheet(
      title: 'تحديد الكلفة التقديرية',
      message: 'سيتم إرسال الكلفة إلى المالك للموافقة قبل بدء العمل.',
      initialCost: _request?.estimatedCost,
      actionLabel: 'إرسال للمالك',
      requireNotes: true,
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).setEstimate(
            requestId: widget.requestId,
            cost: result.$1,
            notes: result.$2.isEmpty ? null : result.$2,
          );
      _invalidate();
      await _load();
      if (mounted) showSuccess(context, 'تم إرسال الكلفة إلى المالك للموافقة');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(MaintenanceRequest request, bool approve) async {
    String? reason;
    if (approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الموافقة'),
          content: Text(
            'هل توافق على كلفة ${formatMoney(request.estimatedCost ?? 0, withCurrency: true, country: _country)} لهذا الطلب؟',
            style: const TextStyle(fontFamily: 'Tajawal', height: 1.6),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('موافقة')),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      reason = await _showReasonDialog();
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).ownerDecision(
            requestId: widget.requestId,
            approve: approve,
            ownerId: widget.viewer.id,
            reason: reason,
          );
      _invalidate();
      await _load();
      if (mounted) {
        showSuccess(context, approve ? 'تمت الموافقة على الطلب' : 'تم رفض الطلب');
      }
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: tr('وضّح سبب الرفض للمدير والمستأجر'),
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.length < 3) return;
              Navigator.pop(context, reason);
            },
            child: const Text('رفض الطلب', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _startWork() async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).startWork(widget.requestId);
      _invalidate();
      await _load();
      if (mounted) showSuccess(context, 'تم بدء تنفيذ الأعمال');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeWork() async {
    final result = await _showCostSheet(
      title: 'إكمال الطلب',
      message: 'سجّل الكلفة النهائية التي تم دفعها فعلياً.',
      initialCost: _request?.estimatedCost,
      actionLabel: 'تأكيد الإكمال',
      requireNotes: false,
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).completeWork(
            requestId: widget.requestId,
            finalCost: result.$1,
            notes: result.$2.isEmpty ? null : result.$2,
          );
      _invalidate();
      await _load();
      if (mounted) showSuccess(context, 'تم إكمال الطلب بنجاح');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء طلب الصيانة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء الطلب', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).cancelRequest(widget.requestId);
      _invalidate();
      await _load();
      if (mounted) showSuccess(context, 'تم إلغاء الطلب');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(double, String)?> _showCostSheet({
    required String title,
    required String message,
    required String actionLabel,
    double? initialCost,
    bool requireNotes = false,
  }) async {
    final costController = TextEditingController(text: initialCost?.toStringAsFixed(0) ?? '');
    final notesController = TextEditingController();
    String? error;

    final result = await showModalBottomSheet<(double, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                ),
                padding: withSystemBottomInset(context, const EdgeInsets.all(AppSpacing.lg)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.request_quote_rounded, color: AppColors.gold),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    Text(
                      message,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, height: 1.6, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold),
                      decoration: InputDecoration(
                        labelText: I18n.isEnglish
                            ? 'Cost (${_country.currencyCode})'
                            : 'الكلفة (${_country.currencyCode})',
                        prefixIcon: Icon(Icons.payments_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: requireNotes ? 'تفاصيل العمل المطلوب' : 'ملاحظات (اختياري)',
                        prefixIcon: const Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        error!,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    GoldButton(
                      label: actionLabel,
                      icon: Icons.check_circle_rounded,
                      onPressed: () {
                        final cost = double.tryParse(costController.text);
                        if (cost == null || cost <= 0) {
                          setSheetState(() => error = 'أدخل كلفة صحيحة أكبر من صفر');
                          return;
                        }
                        if (requireNotes && notesController.text.trim().length < 3) {
                          setSheetState(() => error = 'أضف وصفاً للعمل المطلوب');
                          return;
                        }
                        Navigator.pop(sheetContext, (cost, notesController.text.trim()));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    costController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).sendMessage(
            requestId: widget.requestId,
            senderId: widget.viewer.id,
            body: body,
          );
      _messageController.clear();
      final messages = await ref.read(repositoryProvider).messagesForRequest(widget.requestId);
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (error) {
      if (mounted) {
        showError(
          context,
          friendlyError(error).contains('maintenance_messages')
              ? 'المحادثة غير مهيأة بعد. شغّل ملف supabase/schema.sql.'
              : friendlyError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
