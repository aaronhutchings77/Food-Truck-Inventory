import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';

class ShoppingCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  ShoppingCard({super.key, required this.doc});

  final service = InventoryService();

  /// Calculate required purchase quantity based on overall target.
  /// buyAmount = overallRequired - totalAvailable
  static double getRequiredQuantity(Map<String, dynamic> data) {
    double usedPer = (data["usedPerService"] ?? data["qtyPerService"] ?? 0.0)
        .toDouble();
    double truck = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    double home = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();
    double totalAvailable = truck + home;
    double overallRequired = usedPer * GlobalSettings.targetServices;
    double needed = overallRequired - totalAvailable;
    return needed > 0 ? needed : 0;
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    double requiredQty = getRequiredQuantity(data);
    String unitType = data["unitType"] ?? "units";
    double truck = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    double home = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();
    double total = truck + home;

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDelete(context);
        return false; // Don't dismiss, let the delete button handle it
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          title: Text(
            data["name"] ?? "",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            "Need: ${requiredQty.toStringAsFixed(1)} $unitType\n"
            "On Hand: ${total.toStringAsFixed(1)} $unitType",
            style: const TextStyle(fontSize: 14),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => _purchaseDialog(context, requiredQty),
                child: const Text("Purchase", style: TextStyle(fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                tooltip: "Delete Item",
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _purchaseDialog(BuildContext context, double suggested) {
    final totalController = TextEditingController(
      text: suggested.toStringAsFixed(1),
    );
    String placement = "truck";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Purchase"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: totalController,
                decoration: const InputDecoration(labelText: "Total Bought"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Where was item placed?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: "truck",
                    label: Text("Truck"),
                    icon: Icon(Icons.local_shipping),
                  ),
                  ButtonSegment(
                    value: "home",
                    label: Text("Home"),
                    icon: Icon(Icons.home),
                  ),
                ],
                selected: {placement},
                onSelectionChanged: (v) =>
                    setDialogState(() => placement = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final total = double.tryParse(totalController.text) ?? 0;
                final truckAdd = placement == "truck" ? total : 0.0;
                await service.addPurchase(doc.id, total, truckAdd);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Item?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await service.deleteItem(doc.id);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
