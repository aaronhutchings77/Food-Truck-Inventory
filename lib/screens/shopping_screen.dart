import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/shopping_card.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final Map<String, bool> _expandedCategories = {
    "food": true,
    "service": true,
    "equipment": true,
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("items").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;

        // Filter items that need restocking
        final needsRestock = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          double total =
              (data["truckAmount"] ?? 0.0) + (data["homeAmount"] ?? 0.0);
          return total <= (data["gettingLow"] ?? 0);
        }).toList();

        if (needsRestock.isEmpty) {
          return const Center(child: Text("Nothing needs restocking."));
        }

        // Group by category
        final foodItems = needsRestock.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data["category"] ?? "food") == "food";
        }).toList();

        final serviceItems = needsRestock.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data["category"] ?? "food") == "service";
        }).toList();

        final equipmentItems = needsRestock.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data["category"] ?? "food") == "equipment";
        }).toList();

        return ListView(
          children: [
            _categorySection("Food", foodItems),
            _categorySection("Service", serviceItems),
            _categorySection("Equipment", equipmentItems),
          ],
        );
      },
    );
  }

  Widget _categorySection(String title, List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            title: Text(title),
            trailing: IconButton(
              icon: Icon(
                _expandedCategories[title.toLowerCase()] ?? false
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              onPressed: () {
                setState(() {
                  _expandedCategories[title.toLowerCase()] =
                      !(_expandedCategories[title.toLowerCase()] ?? false);
                });
              },
            ),
          ),
          if (_expandedCategories[title.toLowerCase()] ?? false)
            ...docs.map((doc) => ShoppingCard(doc: doc)),
        ],
      ),
    );
  }
}
