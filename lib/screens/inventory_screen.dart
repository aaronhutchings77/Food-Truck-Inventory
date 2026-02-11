import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/inventory_card.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection("items").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> critical = [];
        List<QueryDocumentSnapshot> low = [];
        List<QueryDocumentSnapshot> good = [];

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;

          double total =
              (data["truckAmount"] ?? 0.0) + (data["homeAmount"] ?? 0.0);
          double per = data["amountPerService"] ?? 1.0;
          double services = per > 0 ? total / per : 0;

          if (services <= (data["criticalServices"] ?? 0)) {
            critical.add(doc);
          } else if (services <= (data["lowWarningServices"] ?? 0)) {
            low.add(doc);
          } else {
            good.add(doc);
          }
        }

        return ListView(
          children: [
            _section("🚨 Critical", critical),
            _section("⚠️ Low", low),
            _section("✅ Good", good),
          ],
        );
      },
    );
  }

  Widget _section(String title, List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...docs.map((doc) => InventoryCard(doc: doc)),
      ],
    );
  }
}
