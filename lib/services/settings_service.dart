import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsService {
  final _db = FirebaseFirestore.instance.collection("app_settings");

  static const String _doc = "inventory";
  static const int defaultTargetServices = 5;
  static const int defaultTruckTargetServices = 3;
  static const int defaultLowMultiplier = 2;
  static const int defaultCriticalMultiplier = 1;

  Stream<Map<String, int>> getSettingsStream() {
    return _db.doc(_doc).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return {
        "targetServices": data["targetServices"] ?? defaultTargetServices,
        "truckTargetServices":
            data["truckTargetServices"] ?? defaultTruckTargetServices,
        "lowServiceMultiplier":
            data["lowServiceMultiplier"] ?? defaultLowMultiplier,
        "criticalServiceMultiplier":
            data["criticalServiceMultiplier"] ?? defaultCriticalMultiplier,
      };
    });
  }

  Stream<Map<String, Timestamp?>> getInventorySessionsStream() {
    return _db.doc(_doc).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return {
        "lastInventoryStartedAt_perService":
            data["lastInventoryStartedAt_perService"],
        "lastInventoryStartedAt_daily": data["lastInventoryStartedAt_daily"],
        "lastInventoryStartedAt_weekly": data["lastInventoryStartedAt_weekly"],
        "lastInventoryStartedAt_monthly":
            data["lastInventoryStartedAt_monthly"],
        "lastInventoryStartedAt_quarterly":
            data["lastInventoryStartedAt_quarterly"],
        "lastInventoryStartedAt_warnings":
            data["lastInventoryStartedAt_warnings"],
        "lastInventoryStartedAt_all": data["lastInventoryStartedAt_all"],
        "lastTruckInventoryStartedAt_perService":
            data["lastTruckInventoryStartedAt_perService"],
        "lastTruckInventoryStartedAt_daily":
            data["lastTruckInventoryStartedAt_daily"],
        "lastTruckInventoryStartedAt_weekly":
            data["lastTruckInventoryStartedAt_weekly"],
        "lastTruckInventoryStartedAt_monthly":
            data["lastTruckInventoryStartedAt_monthly"],
        "lastTruckInventoryStartedAt_quarterly":
            data["lastTruckInventoryStartedAt_quarterly"],
        "lastTruckInventoryStartedAt_warnings":
            data["lastTruckInventoryStartedAt_warnings"],
        "lastTruckInventoryStartedAt_all":
            data["lastTruckInventoryStartedAt_all"],
        "lastHomeInventoryStartedAt_perService":
            data["lastHomeInventoryStartedAt_perService"],
        "lastHomeInventoryStartedAt_daily":
            data["lastHomeInventoryStartedAt_daily"],
        "lastHomeInventoryStartedAt_weekly":
            data["lastHomeInventoryStartedAt_weekly"],
        "lastHomeInventoryStartedAt_monthly":
            data["lastHomeInventoryStartedAt_monthly"],
        "lastHomeInventoryStartedAt_quarterly":
            data["lastHomeInventoryStartedAt_quarterly"],
        "lastHomeInventoryStartedAt_warnings":
            data["lastHomeInventoryStartedAt_warnings"],
        "lastHomeInventoryStartedAt_all":
            data["lastHomeInventoryStartedAt_all"],
      };
    });
  }

  Future<Map<String, int>> getSettings() async {
    final snapshot = await _db.doc(_doc).get();
    final data = snapshot.data() ?? {};
    return {
      "targetServices": data["targetServices"] ?? defaultTargetServices,
      "truckTargetServices":
          data["truckTargetServices"] ?? defaultTruckTargetServices,
      "lowServiceMultiplier":
          data["lowServiceMultiplier"] ?? defaultLowMultiplier,
      "criticalServiceMultiplier":
          data["criticalServiceMultiplier"] ?? defaultCriticalMultiplier,
    };
  }

  Future<void> updateSettings(Map<String, int> settings) async {
    await _db.doc(_doc).set({
      ...settings,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> initializeDefaultSettings() async {
    final doc = await _db.doc(_doc).get();
    if (!doc.exists) {
      await updateSettings({
        "targetServices": defaultTargetServices,
        "truckTargetServices": defaultTruckTargetServices,
        "lowServiceMultiplier": defaultLowMultiplier,
        "criticalServiceMultiplier": defaultCriticalMultiplier,
      });
    } else {
      // Migrate old servicesTarget field if present
      final data = doc.data() ?? {};
      if (data.containsKey("servicesTarget") &&
          !data.containsKey("targetServices")) {
        await _db.doc(_doc).update({"targetServices": data["servicesTarget"]});
      }
    }
  }

  Future<void> updateInventorySession(String tabKey) async {
    await _db.doc(_doc).update({
      "lastInventoryStartedAt_$tabKey": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTruckInventorySession(String tabKey) async {
    await _db.doc(_doc).update({
      "lastTruckInventoryStartedAt_$tabKey": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateHomeInventorySession(String tabKey) async {
    await _db.doc(_doc).update({
      "lastHomeInventoryStartedAt_$tabKey": FieldValue.serverTimestamp(),
    });
  }
}
