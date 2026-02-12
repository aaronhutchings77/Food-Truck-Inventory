import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryService {
  final _db = FirebaseFirestore.instance.collection("items");

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
      "truckAmount": FieldValue.increment(truckAdd),
      "homeAmount": FieldValue.increment(homeAdd),
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

  Stream<QuerySnapshot> getItemsByFrequency(String checkFrequency) {
    return _db.where("checkFrequency", isEqualTo: checkFrequency).snapshots();
  }

  Stream<QuerySnapshot> getAllItems() {
    return _db.snapshots();
  }
}
