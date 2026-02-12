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
}
