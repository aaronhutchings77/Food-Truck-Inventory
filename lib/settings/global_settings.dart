import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/settings_service.dart';

class GlobalSettings {
  static final SettingsService _settingsService = SettingsService();

  static int _targetServices = 5;
  static int _truckTargetServices = 3;
  static int _lowServiceMultiplier = 2;
  static int _criticalServiceMultiplier = 1;

  // Inventory session timestamps
  static Map<String, Timestamp?> _inventorySessions = {};

  static int get targetServices => _targetServices;
  static int get truckTargetServices => _truckTargetServices;
  static int get lowServiceMultiplier => _lowServiceMultiplier;
  static int get criticalServiceMultiplier => _criticalServiceMultiplier;

  static Timestamp? getInventorySession(String tabKey) {
    return _inventorySessions["lastInventoryStartedAt_$tabKey"];
  }

  static Timestamp? getTruckInventorySession(String tabKey) {
    return _inventorySessions["lastTruckInventoryStartedAt_$tabKey"];
  }

  static Timestamp? getHomeInventorySession(String tabKey) {
    return _inventorySessions["lastHomeInventoryStartedAt_$tabKey"];
  }

  static void initialize(Map<String, int> settings) {
    _targetServices = settings["targetServices"] ?? 5;
    _truckTargetServices = settings["truckTargetServices"] ?? 3;
    _lowServiceMultiplier = settings["lowServiceMultiplier"] ?? 2;
    _criticalServiceMultiplier = settings["criticalServiceMultiplier"] ?? 1;
  }

  static void initializeInventorySessions(Map<String, Timestamp?> sessions) {
    _inventorySessions = sessions;
  }

  static Future<void> updateInventorySession(String tabKey) async {
    await _settingsService.updateInventorySession(tabKey);
  }

  static Future<void> updateTruckInventorySession(String tabKey) async {
    await _settingsService.updateTruckInventorySession(tabKey);
  }

  static Future<void> updateHomeInventorySession(String tabKey) async {
    await _settingsService.updateHomeInventorySession(tabKey);
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

  static Stream<Map<String, Timestamp?>> get inventorySessionsStream =>
      _settingsService.getInventorySessionsStream();
}
