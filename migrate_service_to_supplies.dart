import 'package:cloud_firestore/cloud_firestore.dart';

/// Migration script to update all items with category "service" to "supplies"
/// Run this once to migrate existing data
Future<void> migrateServiceToSupplies() async {
  final firestore = FirebaseFirestore.instance;
  final itemsCollection = firestore.collection('items');
  
  print('Starting migration from "service" to "supplies"...');
  
  try {
    // Get all items with category "service"
    final querySnapshot = await itemsCollection.where('category', isEqualTo: 'service').get();
    
    if (querySnapshot.docs.isEmpty) {
      print('No items found with category "service". Migration complete.');
      return;
    }
    
    print('Found ${querySnapshot.docs.length} items to migrate.');
    
    // Update each item
    for (final doc in querySnapshot.docs) {
      await doc.reference.update({'category': 'supplies'});
      print('Updated item: ${doc.id}');
    }
    
    print('Migration completed successfully!');
    
  } catch (e) {
    print('Error during migration: $e');
  }
}

/// You can run this function from your main.dart temporarily or create a separate script
/// For example, add this to main.dart and call it once:
/// 
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp(...);
///   
///   // Run migration once
///   await migrateServiceToSupplies();
///   
///   runApp(MyApp());
/// }
