import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';
import '../screens/edit_item_screen.dart';

class InventoryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  InventoryCard({super.key, required this.doc});

  final service = InventoryService();

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    double truck = data["truckAmount"] ?? 0.0;
    double home = data["homeAmount"] ?? 0.0;
    double qtyPerService = data["qtyPerService"] ?? 1.0;
    String unitType = data["unitType"] ?? "units";
    String model = data["model"] ?? "";

    double total = truck + home;
    double servicesRemaining = qtyPerService > 0 ? total / qtyPerService : 0;

    Color status = Colors.green;

    if (total <= (data["needToPurchase"] ?? 0) ||
        servicesRemaining < GlobalSettings.servicesTarget) {
      status = Colors.red;
    } else if (total <= (data["gettingLow"] ?? 0)) {
      status = Colors.orange;
    }

    String subtitle = "Current: $total ($unitType)";
    if (qtyPerService > 0) {
      subtitle +=
          "\nServices Remaining: ${servicesRemaining.toStringAsFixed(1)}";
    }
    if (model.isNotEmpty) {
      subtitle += "\nModel: $model";
    }

    return Card(
      color: status.withOpacity(0.1),
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditItemScreen(doc: doc)),
          );
        },
        child: ListTile(
          title: Text(data["name"]),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditItemScreen(doc: doc),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteConfirmation(context),
              ),
            ],
          ),
        ),
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
