import '../services/settings_service.dart';

class GlobalSettings {
  static final SettingsService _settingsService = SettingsService();

  static int _targetServices = 5;
  static int _truckTargetServices = 3;
  static int _lowServiceMultiplier = 2;
  static int _criticalServiceMultiplier = 1;

  static int get targetServices => _targetServices;
  static int get truckTargetServices => _truckTargetServices;
  static int get lowServiceMultiplier => _lowServiceMultiplier;
  static int get criticalServiceMultiplier => _criticalServiceMultiplier;

  static void initialize(Map<String, int> settings) {
    _targetServices = settings["targetServices"] ?? 5;
    _truckTargetServices = settings["truckTargetServices"] ?? 3;
    _lowServiceMultiplier = settings["lowServiceMultiplier"] ?? 2;
    _criticalServiceMultiplier = settings["criticalServiceMultiplier"] ?? 1;
  }

  static Future<void> updateAll({
    required int targetServices,
    required int truckTargetServices,
    required int lowServiceMultiplier,
    required int criticalServiceMultiplier,
  }) async {
    final settings = {
      "targetServices": targetServices,
      "truckTargetServices": truckTargetServices,
      "lowServiceMultiplier": lowServiceMultiplier,
      "criticalServiceMultiplier": criticalServiceMultiplier,
    };
    await _settingsService.updateSettings(settings);
    initialize(settings);
  }

  static Stream<Map<String, int>> get settingsStream =>
      _settingsService.getSettingsStream();
}
