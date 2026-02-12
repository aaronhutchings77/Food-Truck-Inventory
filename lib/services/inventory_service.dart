import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryService {
  final _db = FirebaseFirestore.instance.collection("items");
  final _settingsDb = FirebaseFirestore.instance.collection("app_settings");

  double snap(double value) {
    if (value < 0) return 0;
    return (value * 2).round() / 2;
  }

  Future<void> updateField(String id, String field, double value) async {
    await _db.doc(id).update({
      field: snap(value),
      "updatedAt": FieldValue.serverTimestamp(),
      "updatedBy": FirebaseAuth.instance.currentUser?.email,
    });
  }

  Future<void> addPurchase(String id, double total, double truckAdd) async {
    total = snap(total);
    truckAdd = snap(truckAdd);
    double homeAdd = snap(total - truckAdd);

    await _db.doc(id).update({
      "truckQuantity": FieldValue.increment(truckAdd),
      "homeQuantity": FieldValue.increment(homeAdd),
      "updatedAt": FieldValue.serverTimestamp(),
      "updatedBy": FirebaseAuth.instance.currentUser?.email,
    });
  }

  Future<void> addItem(Map<String, dynamic> data) async {
    await _db.add({
      ...data,
      "updatedAt": FieldValue.serverTimestamp(),
      "updatedBy": FirebaseAuth.instance.currentUser?.email,
    });
  }

  Future<void> updateItem(String id, Map<String, dynamic> data) async {
    await _db.doc(id).update({
      ...data,
      "updatedAt": FieldValue.serverTimestamp(),
      "updatedBy": FirebaseAuth.instance.currentUser?.email,
    });
  }

  Future<void> deleteItem(String id) async {
    await _db.doc(id).delete();
  }

  Future<void> markAsChecked(String id) async {
    await _db.doc(id).update({
      "lastCheckedAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "updatedBy": FirebaseAuth.instance.currentUser?.email,
    });
  }

  Future<void> setTruckVerified(String id, bool verified) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (verified) {
      await _db.doc(id).update({
        "truckVerifiedAt": FieldValue.serverTimestamp(),
        "truckVerifiedBy": email,
        "updatedAt": FieldValue.serverTimestamp(),
        "updatedBy": email,
      });
    } else {
      await _db.doc(id).update({
        "truckVerifiedAt": null,
        "truckVerifiedBy": null,
        "updatedAt": FieldValue.serverTimestamp(),
        "updatedBy": email,
      });
    }
  }

  Future<void> bulkUpdate(List<String> ids, Map<String, dynamic> fields) async {
    final batch = FirebaseFirestore.instance.batch();
    final email = FirebaseAuth.instance.currentUser?.email;
    for (final id in ids) {
      batch.update(_db.doc(id), {
        ...fields,
        "updatedAt": FieldValue.serverTimestamp(),
        "updatedBy": email,
      });
    }
    await batch.commit();
  }

  Stream<QuerySnapshot> getItemsByFrequency(String frequency) {
    return _db.where("inventoryFrequency", isEqualTo: frequency).snapshots();
  }

  Stream<QuerySnapshot> getAllItems() {
    return _db.snapshots();
  }

  /// Run one-time migration for all item documents.
  /// Safe to call multiple times — checks a flag in app_settings.
  Future<void> runMigration() async {
    try {
      final migrationDoc = await _settingsDb.doc("migration").get();
      final migrationData = migrationDoc.data() ?? {};
      if (migrationData["v2_completed"] == true) return;

      final snapshot = await _db.get();
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final updates = <String, dynamic>{};

        // Rename truckAmount → truckQuantity
        if (data.containsKey("truckAmount") &&
            !data.containsKey("truckQuantity")) {
          updates["truckQuantity"] = data["truckAmount"];
          updates["truckAmount"] = FieldValue.delete();
        }

        // Rename homeAmount → homeQuantity
        if (data.containsKey("homeAmount") &&
            !data.containsKey("homeQuantity")) {
          updates["homeQuantity"] = data["homeAmount"];
          updates["homeAmount"] = FieldValue.delete();
        }

        // Rename qtyPerService → usedPerService
        if (data.containsKey("qtyPerService") &&
            !data.containsKey("usedPerService")) {
          updates["usedPerService"] = data["qtyPerService"];
          updates["qtyPerService"] = FieldValue.delete();
        }

        // Rename checkFrequency → inventoryFrequency
        if (data.containsKey("checkFrequency") &&
            !data.containsKey("inventoryFrequency")) {
          String freq = data["checkFrequency"] ?? "perService";
          if (freq == "service") freq = "perService";
          updates["inventoryFrequency"] = freq;
          updates["checkFrequency"] = FieldValue.delete();
        }

        // Migrate category "service" → "supplies"
        if (data["category"] == "service") {
          updates["category"] = "supplies";
        }

        // Migrate old quantity-based thresholds to service-based overrides
        double usedPer =
            (data["usedPerService"] ?? data["qtyPerService"] ?? 1.0).toDouble();
        if (usedPer <= 0) usedPer = 1.0;

        bool hasOldThresholds =
            data.containsKey("gettingLow") ||
            data.containsKey("needToPurchase") ||
            data.containsKey("lowWarningServices");

        if (hasOldThresholds && data["overrideWarnings"] != true) {
          if (data.containsKey("lowWarningServices")) {
            updates["overrideWarnings"] = true;
            updates["gettingLowServices"] = data["lowWarningServices"];
            updates["lowWarningServices"] = FieldValue.delete();
          } else if (data.containsKey("gettingLow") &&
              (data["gettingLow"] ?? 0) > 0) {
            double lowQty = (data["gettingLow"] ?? 0).toDouble();
            double critQty = (data["needToPurchase"] ?? 0).toDouble();
            int lowServices = (lowQty / usedPer).ceil();
            int critServices = (critQty / usedPer).ceil();
            if (lowServices > 0 || critServices > 0) {
              updates["overrideWarnings"] = true;
              updates["gettingLowServices"] = lowServices;
              updates["criticalServices"] = critServices;
            }
          }
          // Clean up old fields
          updates["gettingLow"] = FieldValue.delete();
          updates["needToPurchase"] = FieldValue.delete();
        }

        // Clean up removed fields
        if (data.containsKey("required")) {
          updates["required"] = FieldValue.delete();
        }

        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
        }
      }

      await batch.commit();

      // Mark migration complete
      await _settingsDb.doc("migration").set({
        "v2_completed": true,
        "v2_completedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Migration error (non-blocking): $e");
    }
  }
}
