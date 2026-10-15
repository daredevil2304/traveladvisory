import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  static final ShorebirdService _instance = ShorebirdService._internal();
  factory ShorebirdService() => _instance;
  ShorebirdService._internal();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  final ValueNotifier<int?> currentPatchNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<bool> isUpdateAvailableNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isUpdateReadyNotifier = ValueNotifier<bool>(false);

  bool get isShorebirdAvailable => _updater.isAvailable;

  Future<void> init() async {
    if (!isShorebirdAvailable) {
      debugPrint('[Shorebird] Running standard Flutter engine (Shorebird inactive).');
      return;
    }

    try {
      final patch = await _updater.readCurrentPatch();
      currentPatchNotifier.value = patch?.number;
      debugPrint('[Shorebird] Active patch number: ${patch?.number}');

      unawaited(checkForUpdates());
    } catch (e) {
      debugPrint('[Shorebird] Init error: $e');
    }
  }

  Future<void> checkForUpdates() async {
    if (!isShorebirdAvailable) return;

    try {
      final status = await _updater.checkForUpdate();
      final hasUpdate = (status == UpdateStatus.outdated);
      isUpdateAvailableNotifier.value = hasUpdate;

      if (status == UpdateStatus.restartRequired) {
        isUpdateReadyNotifier.value = true;
        debugPrint('[Shorebird] OTA patch ready! App restart will apply changes.');
        return;
      }

      if (hasUpdate) {
        debugPrint('[Shorebird] New OTA patch available! Downloading...');
        isDownloadingNotifier.value = true;
        await _updater.update();
        isDownloadingNotifier.value = false;
        isUpdateReadyNotifier.value = true;
        debugPrint('[Shorebird] OTA patch downloaded! App restart will apply changes.');
      } else {
        debugPrint('[Shorebird] App is on the latest available OTA patch.');
      }
    } catch (e) {
      isDownloadingNotifier.value = false;
      debugPrint('[Shorebird] Update check error: $e');
    }
  }
}
