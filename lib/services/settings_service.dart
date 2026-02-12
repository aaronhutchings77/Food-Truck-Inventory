import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsService {
  final _db = FirebaseFirestore.instance.collection("app_settings");

  static const String _inventoryDoc = "inventory";
  static const String _servicesTargetField = "servicesTarget";
  static const int _defaultServicesTarget = 5;

  Stream<int> getServicesTargetStream() {
    return _db.doc(_inventoryDoc).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data?[_servicesTargetField] ?? _defaultServicesTarget;
    });
  }

  Future<int> getServicesTarget() async {
    final snapshot = await _db.doc(_inventoryDoc).get();
    final data = snapshot.data();
    return data?[_servicesTargetField] ?? _defaultServicesTarget;
  }

  Future<void> setServicesTarget(int target) async {
    await _db.doc(_inventoryDoc).set({
      _servicesTargetField: target,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> initializeDefaultSettings() async {
    final doc = await _db.doc(_inventoryDoc).get();
    if (!doc.exists) {
      await setServicesTarget(_defaultServicesTarget);
    }
  }
}
