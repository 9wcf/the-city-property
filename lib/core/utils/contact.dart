import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_utils.dart';

Future<void> openPhoneCall(String? phone) async {
  if (phone == null || phone.trim().isEmpty) return;
  final uri = Uri(scheme: 'tel', path: phone.trim());
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openWhatsApp(String? phone, {String? message}) async {
  if (phone == null || phone.trim().isEmpty) return;
  final digits = toE164Iraq(phone).replaceAll(RegExp(r'[^0-9]'), '');
  final query = message == null ? '' : '?text=${Uri.encodeComponent(message)}';
  final uri = Uri.parse('https://wa.me/$digits$query');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openMap(String? location) async {
  if (location == null || location.trim().isEmpty) return;
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Widget contactActions({
  required BuildContext context,
  String? phone,
  String? message,
  Color color = const Color(0xFF2ECC8F),
}) {
  return Row(
    children: [
      Expanded(
        child: _ContactButton(
          icon: Icons.call_rounded,
          label: 'اتصال',
          color: color,
          onTap: () => openPhoneCall(phone),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ContactButton(
          icon: Icons.chat_rounded,
          label: 'واتساب',
          color: color,
          onTap: () => openWhatsApp(phone, message: message),
        ),
      ),
    ],
  );
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
