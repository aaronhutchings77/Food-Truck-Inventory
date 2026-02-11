import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';

class ShoppingCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  ShoppingCard({super.key, required this.doc});

  final service = InventoryService();

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    double total = (data["truckAmount"] ?? 0.0) + (data["homeAmount"] ?? 0.0);
    String unitType = data["unitType"] ?? "units";
    double optimal =
        (data["qtyPerService"] ?? 1.0) * GlobalSettings.planForServices;
    double suggested = optimal - total;
    if (suggested < 0) suggested = 0;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(data["name"]),
        subtitle: Text(
          "Suggested: ${suggested.toStringAsFixed(1)} ($unitType)",
        ),
        trailing: ElevatedButton(
          child: const Text("Purchase"),
          onPressed: () => _purchaseDialog(context, suggested),
        ),
      ),
    );
  }

  void _purchaseDialog(BuildContext context, double suggested) {
    final totalController = TextEditingController(
      text: suggested.toStringAsFixed(1),
    );
    final truckController = TextEditingController(text: "0");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Purchase"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: totalController,
              decoration: const InputDecoration(labelText: "Total Bought"),
            ),
            TextField(
              controller: truckController,
              decoration: const InputDecoration(labelText: "Add To Truck"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await service.addPurchase(
                doc.id,
                double.tryParse(totalController.text) ?? 0,
                double.tryParse(truckController.text) ?? 0,
              );
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
