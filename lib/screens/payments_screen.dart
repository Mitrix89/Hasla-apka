import 'package:flutter/material.dart';

import '../theme.dart';

/// Opłaty i przypomnienia powstaną w kolejnym kroku planu.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opłaty i przypomnienia')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_outlined, size: 48, color: AppColors.payments),
              SizedBox(height: 16),
              Text('Wkrótce', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                'Tu pojawią się subskrypcje, rachunki i przypomnienia o terminach.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
