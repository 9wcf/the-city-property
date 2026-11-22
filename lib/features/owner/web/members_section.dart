import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/i18n/app_country.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/widgets/premium_widgets.dart';
import '../../../data/models.dart';
import '../../../data/repositories.dart';
import 'web_ui.dart';

class MembersSection extends ConsumerStatefulWidget {
  const MembersSection({super.key});

  @override
  ConsumerState<MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends ConsumerState<MembersSection> {
  String _filter = 'الكل';
  String _query = '';

  Future<void> _refresh() async {
    ref.invalidate(ownerSnapshotProvider);
    ref.invalidate(ownerDashboardProvider);
    await ref.read(ownerDashboardProvider.future);
  }

  List<MemberRow> _apply(List<MemberRow> members) {
    final query = _query.trim();
    return members.where((member) {
      final matchesFilter = switch (_filter) {
        'المستأجرون' => member.role == UserRole.tenant,
        'المديرون' => member.role == UserRole.manager,
        'الموقوفون' => !member.isActive,
        _ => true,
      };
      final matchesQuery = query.isEmpty ||
          member.fullName.contains(query) ||
          member.phoneNumber.contains(query) ||
          member.scope.contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ownerDashboardProvider);
    final country = ref.watch(ownerCountryProvider);
    final compoundAssignments = ref.watch(compoundManagersProvider);
    final apartmentAssignments = ref.watch(apartmentManagersProvider);
    return async.when(
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
        final snapshot = data.snapshot;
        final countryCompounds =
            snapshot.portfolio.compounds.where((c) => c.country == country);
        final countryCompoundIds =
            countryCompounds.map((compound) => compound.id).toSet();
        final countryApartmentIds = snapshot.portfolio.apartments
            .where((apartment) => apartment.country == country)
            .map((apartment) => apartment.id)
            .toSet();
        final tenantIds = <String>{
          ...snapshot.tenants
              .where((tenant) => tenant.apartment.country == country)
              .map((tenant) => tenant.profile.id),
          ...snapshot.archivedTenants
              .where((record) => record.apartment.country == country)
              .map((record) => record.profile.id),
        };
        final managerIds = <String>{
          ...compoundAssignments.maybeWhen(
            data: (value) => value
                .where((assignment) =>
                    countryCompoundIds.contains(assignment.compoundId))
                .map((assignment) => assignment.managerId),
            orElse: () => const <String>[],
          ),
          ...apartmentAssignments.maybeWhen(
            data: (value) => value
                .where((assignment) =>
                    countryApartmentIds.contains(assignment.apartmentId))
                .map((assignment) => assignment.managerId),
            orElse: () => const <String>[],
          ),
        };
        final countryMembers = data.members
            .where((member) =>
                member.role == UserRole.owner ||
                tenantIds.contains(member.id) ||
                managerIds.contains(member.id))
            .toList();
        final members = _apply(countryMembers);
        final inactive =
            countryMembers.where((member) => !member.isActive).length;
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WebPageHeader(
                title: 'الأعضاء',
                subtitle:
                    'تحكم كامل في المستأجرين والمديرين في ${country.name(english: I18n.isEnglish)}: التفعيل، تعيين النطاق، وكلمات المرور',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('تحديث'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _createManager(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('إضافة مدير'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebKpiGrid(
                children: [
                  WebKpiCard(
                    label: 'إجمالي الأعضاء',
                    value: '${countryMembers.length}',
                    icon: Icons.groups_rounded,
                    color: AppColors.gold,
                    caption: 'في هذه الدولة',
                  ),
                  WebKpiCard(
                    label: 'المستأجرون',
                    value: '${tenantIds.length}',
                    icon: Icons.person_rounded,
                    color: AppColors.info,
                  ),
                  WebKpiCard(
                    label: 'المديرون',
                    value: '${managerIds.length}',
                    icon: Icons.support_agent_rounded,
                    color: AppColors.reserved,
                  ),
                  WebKpiCard(
                    label: 'حسابات موقوفة',
                    value: '$inactive',
                    icon: Icons.person_off_rounded,
                    color: inactive == 0 ? AppColors.textMuted : AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              WebPanel(
                title: 'قائمة الأعضاء',
                subtitle: '${members.length} عضو مطابق',
                action: SizedBox(
                  width: 260,
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: tr('بحث بالاسم أو الهاتف أو النطاق'),
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['الكل', 'المستأجرون', 'المديرون', 'الموقوفون']
                          .map(
                            (filter) => WebToolbarChip(
                              label: filter,
                              selected: _filter == filter,
                              onTap: () => setState(() => _filter = filter),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    WebTable(
                      empty: const WebEmpty(
                        icon: Icons.group_off_rounded,
                        title: 'لا توجد نتائج',
                        message: 'جرّب تغيير التصنيف أو كلمة البحث.',
                      ),
                      columns: const [
                        WebTableColumn('العضو', flex: 3),
                        WebTableColumn('الدور', flex: 2),
                        WebTableColumn('النطاق', flex: 3),
                        WebTableColumn('الحالة', flex: 2, align: TextAlign.center),
                        WebTableColumn('الانضمام', flex: 2),
                        WebTableColumn('إجراءات', flex: 2, align: TextAlign.center),
                      ],
                      rows: members
                          .map(
                            (member) => [
                              _MemberIdentity(member: member),
                              WebPill(
                                label: member.role.label,
                                color: switch (member.role) {
                                  UserRole.owner => AppColors.gold,
                                  UserRole.manager => AppColors.reserved,
                                  UserRole.tenant => AppColors.info,
                                },
                                icon: member.role.icon,
                              ),
                              Text(
                                member.scope,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              WebPill(
                                label: member.isActive ? 'نشط' : 'موقوف',
                                color: member.isActive
                                    ? AppColors.occupied
                                    : AppColors.danger,
                              ),
                              Text(
                                member.createdAt == null
                                    ? '—'
                                    : formatDate(member.createdAt!),
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  WebRowAction(
                                    icon: Icons.password_rounded,
                                    tooltip: tr('إعادة تعيين كلمة المرور'),
                                    onTap: () => _resetPassword(context, member),
                                  ),
                                  const SizedBox(width: 6),
                                  WebRowAction(
                                    icon: member.isActive
                                        ? Icons.pause_circle_outline_rounded
                                        : Icons.play_circle_outline_rounded,
                                    tooltip: member.isActive ? tr('إيقاف الحساب') : tr('تفعيل الحساب'),
                                    color: member.isActive
                                        ? AppColors.danger
                                        : AppColors.occupied,
                                    onTap: () => _toggleMember(member),
                                  ),
                                ],
                              ),
                            ],
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _MembersHint(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createManager(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateManagerDialog(
        repository: ref.read(repositoryProvider),
        initialCountry: ref.read(ownerCountryProvider),
      ),
    );
    if (created == true && context.mounted) {
      ref.invalidate(ownerDashboardProvider);
      ref.invalidate(apartmentManagersProvider);
      showSuccess(context, 'تم إنشاء حساب المدير بنجاح');
    }
  }

  Future<void> _resetPassword(BuildContext context, MemberRow member) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        repository: ref.read(repositoryProvider),
        member: member,
      ),
    );
    if (changed == true && context.mounted) {
      showSuccess(context, 'تم تحديث كلمة مرور ${member.fullName}');
    }
  }

  Future<void> _toggleMember(MemberRow member) async {
    final activate = !member.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activate ? 'تفعيل الحساب' : 'إيقاف الحساب'),
        content: Text(
          activate
              ? 'سيتمكن ${member.fullName} من الدخول إلى النظام مرة أخرى.'
              : 'سيتم منع ${member.fullName} من الدخول إلى النظام مع الاحتفاظ بكل بياناته.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              activate ? 'تفعيل' : 'إيقاف',
              style: TextStyle(
                color: activate ? AppColors.occupied : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).setMemberActive(
            memberId: member.id,
            active: activate,
          );
      ref.invalidate(ownerDashboardProvider);
      if (mounted) {
        showSuccess(context, activate ? 'تم تفعيل الحساب' : 'تم إيقاف الحساب');
      }
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }
}

class _MemberIdentity extends StatelessWidget {
  const _MemberIdentity({required this.member});

  final MemberRow member;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(name: member.fullName, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                member.fullName,
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
                prettyPhone(member.phoneNumber),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MembersHint extends StatelessWidget {
  const _MembersHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.info.withValues(alpha: .18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'المستأجر يظهر تلقائياً عند ارتباطه بعقد سكن أو طلب سكن. لإضافة مدير جديد أدخله من زر «إضافة مدير»، ثم عيّن له عقارات أو شققاً من قسم المديرين.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateManagerDialog extends StatefulWidget {
  const _CreateManagerDialog({
    required this.repository,
    required this.initialCountry,
  });

  final SupabaseRepository repository;
  final AppCountry initialCountry;

  @override
  State<_CreateManagerDialog> createState() => _CreateManagerDialogState();
}

class _CreateManagerDialogState extends State<_CreateManagerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late AppCountry _country = widget.initialCountry;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final phone = _country.normalizePhone(_phone.text);
    final password = _password.text;
    if (name.length < 3) {
      setState(() => _error = 'أدخل الاسم الكامل للمدير');
      return;
    }
    if (!_country.isValidPhone(phone)) {
      setState(() =>
          _error = 'أدخل رقماً صحيحاً لـ${_country.nameAr} (${_country.phoneHint})');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.createManager(
        fullName: name,
        phone: phone,
        password: password,
        country: _country,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مدير جديد'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                enabled: !_loading,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('الاسم الكامل'),
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<AppCountry>(
                initialValue: _country,
                decoration: InputDecoration(
                  labelText: tr('الدولة'),
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                items: AppCountry.values
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.flag}  ${item.name(english: I18n.isEnglish)} · ${item.dialCode}',
                          ),
                        ))
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value != null) setState(() => _country = value);
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _phone,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('رقم الهاتف (${_country.phoneHint})'),
                  prefixIcon: const Icon(Icons.phone_iphone_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _password,
                enabled: !_loading,
                obscureText: _obscure,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('كلمة المرور (8 أحرف على الأقل)'),
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? tr('إظهار') : tr('إخفاء'),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                    ),
                  ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إنشاء الحساب'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.repository,
    required this.member,
  });

  final SupabaseRepository repository;
  final MemberRow member;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (password.length < 8) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.resetMemberPassword(
        memberId: widget.member.id,
        password: password,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('كلمة مرور ${widget.member.fullName}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _password,
                enabled: !_loading,
                obscureText: _obscure,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('كلمة المرور الجديدة'),
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? tr('إظهار') : tr('إخفاء'),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _confirm,
                enabled: !_loading,
                obscureText: _obscure,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('تأكيد كلمة المرور'),
                  prefixIcon: Icon(Icons.lock_reset_rounded),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
