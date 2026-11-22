import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy950,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SplashBackdrop(),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _GlobePainter(progress: _controller.value),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LogoHalo(controller: _controller),
                  const SizedBox(height: 26),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0xFFE8DEF2),
                        AppColors.brandLavender,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'THE CITY PROPERTY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 27,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.2,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 350.ms, duration: 700.ms)
                      .slideY(begin: .25, end: 0, curve: Curves.easeOutCubic),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutExpo,
                    builder: (context, value, _) => Container(
                      width: 120 * value,
                      height: 1.6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brandLavender.withValues(alpha: 0),
                            AppColors.gold,
                            AppColors.brandLavender.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
                  const SizedBox(height: 16),
                  const Text(
                    'إدارة عقارات بمعايير عالمية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      letterSpacing: .4,
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 700.ms),
                  const SizedBox(height: 14),
                  _GlobalChip(controller: _controller)
                      .animate()
                      .fadeIn(delay: 750.ms, duration: 700.ms)
                      .slideY(begin: .4, end: 0),
                  const SizedBox(height: 34),
                  _LoadingBar(controller: _controller),
                  const SizedBox(height: 14),
                  Text(
                    widget.message ?? 'جاري التحميل…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      letterSpacing: .3,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A051B),
                AppColors.navy950,
                Color(0xFF100722),
              ],
            ),
          ),
        ),
        Positioned(
          top: -160,
          left: -120,
          child: _Glow(
            size: 460,
            color: AppColors.brandViolet.withValues(alpha: .55),
          ),
        ),
        Positioned(
          bottom: -200,
          right: -140,
          child: _Glow(
            size: 520,
            color: AppColors.brandPurple.withValues(alpha: .6),
          ),
        ),
        Positioned(
          top: 120,
          right: 60,
          child: _Glow(
            size: 240,
            color: AppColors.gold.withValues(alpha: .10),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _LogoHalo extends StatelessWidget {
  const _LogoHalo({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 330,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final shimmer = (t * 5) % 1;
          final bob = math.sin(t * math.pi * 2) * 5;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                _PulseRing(progress: (t * 2 + i / 3) % 1),
              CustomPaint(
                size: const Size(330, 330),
                painter: _DashedRingPainter(progress: t),
              ),
              Transform.translate(
                offset: Offset(0, bob),
                child: _GlassLogo(shimmer: shimmer),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scale = .62 + progress * .52;
    final opacity = (1 - progress) * .30;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.brandLavender.withValues(alpha: opacity),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

class _GlassLogo extends StatelessWidget {
  const _GlassLogo({required this.shimmer});

  final double shimmer;

  @override
  Widget build(BuildContext context) {
    return BrandLogo(
      width: 210,
      padding: 16,
      radius: 30,
      shadow: false,
      shimmer: shimmer,
    );
  }
}

class _GlobalChip extends StatelessWidget {
  const _GlobalChip({required this.controller});

  final AnimationController controller;

  static const cities = ['العراق -الامارات -امريكا '];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pulse = .55 + .45 * (1 + math.sin(controller.value * math.pi * 4)) / 2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: .045),
            border: Border.all(color: Colors.white.withValues(alpha: .10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.public_rounded,
                size: 14,
                color: AppColors.gold.withValues(alpha: pulse),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < cities.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text(
                      '·',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted.withValues(alpha: .7),
                      ),
                    ),
                  ),
                Text(
                  cities[i],
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    letterSpacing: .3,
                    color: AppColors.textSecondary.withValues(alpha: .85),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value * 4) % 1;
        return Container(
          width: 190,
          height: 3,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: .07),
          ),
          child: Align(
            alignment: Alignment(-1.6 + 3.2 * t, 0),
            child: FractionallySizedBox(
              widthFactor: .42,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x00C5A059),
                      AppColors.gold,
                      Color(0x00C5A059),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: .45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          AppColors.brandLavender.withValues(alpha: 0),
          AppColors.brandLavender.withValues(alpha: .65),
          AppColors.gold.withValues(alpha: .55),
          AppColors.brandLavender.withValues(alpha: 0),
        ],
        stops: const [0, .35, .55, .8],
      ).createShader(rect);

    const dash = 9.0;
    const gap = 9.0;
    final count = (2 * math.pi * radius / (dash + gap)).floor();
    for (var i = 0; i < count; i++) {
      final start = i * (dash + gap) / radius + progress * math.pi * 2;
      canvas.drawArc(rect, start, dash / radius, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .34;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = AppColors.brandLavender.withValues(alpha: .07);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * math.pi * .6);

    canvas.drawCircle(Offset.zero, radius, paint);

    for (var i = 1; i <= 4; i++) {
      final y = -radius + (radius * 2) * i / 5;
      final half = math.sqrt(math.max(0, radius * radius - y * y));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, y),
          width: half * 2,
          height: half * .42,
        ),
        paint,
      );
    }

    for (var i = 0; i < 6; i++) {
      final phase = i * math.pi / 6;
      final width = radius * 2 * math.cos(phase).abs();
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: math.max(2, width),
          height: radius * 2,
        ),
        paint,
      );
    }

    final node = Paint()
      ..color = AppColors.gold.withValues(alpha: .22)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7 + progress * math.pi * .6;
      final r = radius * .82;
      canvas.drawCircle(
        Offset(math.cos(angle) * r, math.sin(angle) * r * .38),
        1.6,
        node,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
