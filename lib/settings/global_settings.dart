import '../services/settings_service.dart';

class GlobalSettings {
  static final SettingsService _settingsService = SettingsService();
  static int _cachedServicesTarget = 5;

  static int get servicesTarget => _cachedServicesTarget;

  static void initializeServicesTarget(int target) {
    _cachedServicesTarget = target;
  }

  static Future<void> updateServicesTarget(int target) async {
    await _settingsService.setServicesTarget(target);
    _cachedServicesTarget = target;
  }

  static Stream<int> get servicesTargetStream =>
      _settingsService.getServicesTargetStream();
}
