import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';

class InventoryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  InventoryCard({super.key, required this.doc});

  final service = InventoryService();

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    double truck = (data["truckAmount"] ?? 0.0);
    double home = (data["homeAmount"] ?? 0.0);
    double per = (data["amountPerService"] ?? 1.0);

    double services = per > 0 ? (truck + home) / per : 0;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(data["name"]),
        subtitle: Text(
            "Truck: $truck | Home: $home\nServices: ${services.toStringAsFixed(1)}"),
        onTap: () => _editAmounts(context, truck, home),
      ),
    );
  }

  void _editAmounts(BuildContext context, double truck, double home) {
    final truckController = TextEditingController(text: truck.toString());
    final homeController = TextEditingController(text: home.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Amounts"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: truckController,
              decoration: const InputDecoration(labelText: "Truck"),
            ),
            TextField(
              controller: homeController,
              decoration: const InputDecoration(labelText: "Home"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await service.updateField(
                  doc.id,
                  "truckAmount",
                  double.tryParse(truckController.text) ?? truck);
              await service.updateField(
                  doc.id,
                  "homeAmount",
                  double.tryParse(homeController.text) ?? home);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
}
