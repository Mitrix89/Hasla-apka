import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'update/app_updater.dart';
import 'vault/biometric_unlock.dart';
import 'vault/notifications.dart';
import 'vault/vault_controller.dart';
import 'vault/vault_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final controller = VaultController(FileVaultStore('${dir.path}/sejf.hasla'));
  await controller.init();
  runApp(HaslaApp(
    controller: controller,
    biometrics: BiometricUnlock(),
    notifications: PaymentNotifications(),
    updater: AppUpdater(),
  ));
}
