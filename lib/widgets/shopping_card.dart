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
        (data["qtyPerService"] ?? 1.0) * GlobalSettings.servicesTarget;
    double suggested = optimal - total;
    if (suggested < 0) suggested = 0;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(data["name"]),
        subtitle: Text(
          "Suggested: ${suggested.toStringAsFixed(1)} ($unitType)",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              child: const Text("Purchase"),
              onPressed: () => _purchaseDialog(context, suggested),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteConfirmation(context),
            ),
          ],
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
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteConfirmation(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Item"),
        content: Text(
          "Are you sure you want to delete \"${data["name"]}\"? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await service.deleteItem(doc.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
