import 'package:flutter/material.dart';

import '../../data/models.dart';
import 'owner_web_shell.dart';

class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key, required this.profile});

  final AppProfile profile;

  @override
  Widget build(BuildContext context) {
    return OwnerWebShell(profile: profile);
  }
}
