import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter/services.dart';
import 'package:the_city_property/core/theme/app_colors.dart';
import 'package:the_city_property/core/theme/app_spacing.dart';

class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focusNode = FocusNode();
  final _hiddenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hiddenController.text = widget.controller.text;
    widget.controller.addListener(_sync);
    _focusNode.addListener(_refresh);
  }

  void _sync() {
    if (_hiddenController.text != widget.controller.text) {
      _hiddenController.text = widget.controller.text;
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focusNode.removeListener(_refresh);
    _focusNode.dispose();
    _hiddenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusNode.requestFocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final totalGaps = gap * (widget.length - 1);
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 46.0 * widget.length + totalGaps;
          final boxWidth =
              ((available - totalGaps) / widget.length).clamp(38.0, 52.0);
          final boxHeight = (boxWidth * 1.2).clamp(48.0, 62.0);
          return Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.length, (index) {
                  final filled = index < value.length;
                  final active = index == value.length && _focusNode.hasFocus;
                  return Container(
                    width: boxWidth,
                    height: boxHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.gold.withValues(alpha: .10)
                          : Colors.white.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: active
                            ? AppColors.gold
                            : filled
                                ? AppColors.gold.withValues(alpha: .45)
                                : Colors.white.withValues(alpha: .10),
                        width: active ? 1.6 : 1,
                      ),
                      boxShadow: active
                          ? [BoxShadow(color: AppColors.gold.withValues(alpha: .18), blurRadius: 18)]
                          : null,
                    ),
                    child: Text(
                      filled ? value[index] : '',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    controller: _hiddenController,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    showCursor: false,
                    style: const TextStyle(color: Colors.transparent),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                    ),
                    onChanged: (text) {
                      widget.controller.value = TextEditingValue(
                        text: text,
                        selection: TextSelection.collapsed(offset: text.length),
                      );
                      setState(() {});
                      widget.onChanged?.call(text);
                      if (text.length == widget.length) {
                        _focusNode.unfocus();
                        widget.onCompleted?.call(text);
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
