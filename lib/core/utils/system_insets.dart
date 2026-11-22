import 'package:flutter/widgets.dart';

/// Adds the system bottom inset (navigation bar / home indicator) to a padding
/// so sheet and page content never sits underneath it. Reading `viewPadding`
/// as a fallback matters for call sites whose context already had the bottom
/// padding consumed by a [SafeArea]. The inset collapses to zero while the
/// keyboard is open, avoiding a double gap.
EdgeInsets withSystemBottomInset(BuildContext context, EdgeInsets padding) {
  final media = MediaQuery.of(context);
  if (media.viewInsets.bottom > 0) return padding;
  var inset = media.padding.bottom;
  if (inset <= 0) inset = media.viewPadding.bottom;
  if (inset <= 0) return padding;
  return EdgeInsets.fromLTRB(
    padding.left,
    padding.top,
    padding.right,
    padding.bottom + inset,
  );
}
