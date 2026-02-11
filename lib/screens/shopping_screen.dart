import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/shopping_card.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection("items").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          double total =
              (data["truckAmount"] ?? 0.0) + (data["homeAmount"] ?? 0.0);
          double per = data["amountPerService"] ?? 1.0;
          double services = per > 0 ? total / per : 0;

          return services <= (data["lowWarningServices"] ?? 0);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("Nothing needs restocking."));
        }

        return ListView(
          children: docs.map((doc) => ShoppingCard(doc: doc)).toList(),
        );
      },
    );
  }
}
