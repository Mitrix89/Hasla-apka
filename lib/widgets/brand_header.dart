import 'package:flutter/material.dart';

import '../theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Hasła apka', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
