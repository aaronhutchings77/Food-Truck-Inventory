import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

/// One-time migration script to update all items from "service" to "supplies"
/// Run this script once to migrate existing data
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Starting migration from "service" to "supplies"...');

  try {
    final firestore = FirebaseFirestore.instance;
    final itemsCollection = firestore.collection('items');

    // Get all items with category "service"
    final querySnapshot = await itemsCollection
        .where('category', isEqualTo: 'service')
        .get();

    if (querySnapshot.docs.isEmpty) {
      print('No items found with category "service". Migration complete.');
      return;
    }

    print('Found ${querySnapshot.docs.length} items to migrate.');

    // Update each item
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      print('Updating: ${data['name']} (${doc.id})');

      await doc.reference.update({'category': 'supplies'});
    }

    print('Migration completed successfully!');
    print('You can now delete this file.');
  } catch (e) {
    print('Error during migration: $e');
  }
}
