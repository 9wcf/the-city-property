import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_city_property/core/widgets/app_text.dart';

import '../../app/providers.dart';
import '../../core/i18n/app_country.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';

/// شاشة دخول المالك: ثلاث نوافذ مستقلة، كل دولة بعقاراتها وعملتها.
class OwnerCountryHub extends ConsumerWidget {
  const OwnerCountryHub({
    super.key,
    required this.profile,
    required this.onSelected,
    required this.onSignOut,
  });

  final AppProfile profile;
  final ValueChanged<AppCountry> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(ownerDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: PremiumBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async {
              ref.invalidate(ownerDashboardProvider);
              try {
                await ref.read(ownerDashboardProvider.future);
              } catch (_) {
                // The error state below renders the failure.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal:
                    MediaQuery.sizeOf(context).width < 720 ? 16 : 40,
                vertical: 24,
              ),
              children: [
                _Header(
                  profile: profile,
                  onSignOut: onSignOut,
                ),
                const SizedBox(height: AppSpacing.xl),
                dashboard.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  ),
                  error: (error, _) => ErrorView(
                    message: friendlyError(error),
                    onRetry: () => ref.invalidate(ownerDashboardProvider),
                  ),
                  data: (data) {
                    final totalCompounds = data.snapshot.portfolio.compounds.length;
                    final totalUnits = data.snapshot.portfolio.total;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'محفظتك: $totalCompounds عقار · $totalUnits شقة في ثلاث دول',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 1000;
                            final cards = AppCountry.values
                                .map(
                                  (country) => _CountryWindowCard(
                                    country: country,
                                    dashboard: data,
                                    onOpen: () => onSelected(country),
                                  ),
                                )
                                .toList();
                            if (!wide) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < cards.length; i++) ...[
                                    if (i > 0)
                                      const SizedBox(height: AppSpacing.md),
                                    cards[i],
                                  ],
                                ],
                              );
                            }
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < cards.length; i++) ...[
                                    if (i > 0)
                                      const SizedBox(width: AppSpacing.md),
                                    Expanded(child: cards[i]),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const _IsolationNote(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onSignOut});

  final AppProfile profile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return Row(
      children: [
        const BrandLogo(width: 54, padding: 5, radius: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                narrow ? 'اختر الدولة' : 'اختر دولة لإدارة محفظتها',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: narrow ? 17 : 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'عقارات وإيجارات وحسابات منفصلة لكل دولة بعملتها',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: narrow ? 10 : 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const LanguageToggle(compact: true),
        const SizedBox(width: 4),
        IconButton(
          tooltip: tr('تسجيل الخروج'),
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded,
              size: 20, color: AppColors.danger),
        ),
      ],
    );
  }
}

class _CountryWindowCard extends StatelessWidget {
  const _CountryWindowCard({
    required this.country,
    required this.dashboard,
    required this.onOpen,
  });

  final AppCountry country;
  final OwnerDashboardData dashboard;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final compounds = dashboard.snapshot.portfolio.compounds
        .where((compound) => compound.country == country)
        .toList();
    final portfolio = Portfolio(compounds);
    final invoices = dashboard.invoices
        .where((invoice) => invoice.country == country)
        .toList();
    final collectedThisMonth = invoices
        .where((invoice) => isSameMonth(invoice.invoiceDate, DateTime.now()))
        .fold<double>(0, (sum, invoice) => sum + invoice.paidAmount);
    final outstanding =
        invoices.fold<double>(0, (sum, invoice) => sum + invoice.remaining);
    final occupancy = (portfolio.occupancyRate * 100).clamp(0, 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.navy800.withValues(alpha: .95),
                AppColors.navy950.withValues(alpha: .95),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.gold.withValues(alpha: .22)),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: .06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'عقارات ${country.name(english: I18n.isEnglish)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${country.currencyCode} · ${country.currencySymbol(english: I18n.isEnglish)}',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: AppColors.gold),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${compounds.length} عقار · ${portfolio.buildingsCount} عمارة · ${portfolio.total} شقة',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricRow(
                label: 'الإيجار المتوقع شهرياً',
                value: formatMoney(
                  portfolio.monthlyExpected,
                  withCurrency: true,
                  country: country,
                ),
                color: AppColors.gold,
              ),
              const SizedBox(height: 6),
              _MetricRow(
                label: 'محصّل هذا الشهر',
                value: formatMoney(
                  collectedThisMonth,
                  withCurrency: true,
                  country: country,
                ),
                color: AppColors.occupied,
              ),
              const SizedBox(height: 6),
              _MetricRow(
                label: 'مبالغ غير محصّلة',
                value: formatMoney(
                  outstanding,
                  withCurrency: true,
                  country: country,
                ),
                color: outstanding > 0 ? AppColors.pending : AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Text(
                    'الإشغال',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: portfolio.occupancyRate.clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: .06),
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.occupied),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$occupancy%',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.occupied,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text('دخول لوحة ${country.name(english: I18n.isEnglish)}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy900,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _IsolationNote extends StatelessWidget {
  const _IsolationNote();

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
          Icon(Icons.shield_outlined, color: AppColors.info, size: 18),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'كل نافذة دولة معزولة بالكامل: العقارات والمستأجرون والفواتير والمصروفات والمديرون يظهرون داخل دولتها فقط، وكل مبلغ يُعرض بعملة الدولة.',
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
