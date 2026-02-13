import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../widgets/inventory_card.dart';
import '../settings/global_settings.dart';
import '../screens/edit_item_screen.dart';

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

  /// Determine if an item is critical (needs to buy now)
  static bool isCritical(Map<String, dynamic> data) {
    final servicesRemaining = InventoryCard.getServicesRemaining(data);

    bool override = data["overrideWarnings"] == true;
    int critThreshold;

    if (override) {
      critThreshold =
          (data["criticalServices"] ?? GlobalSettings.criticalServiceMultiplier)
              as int;
    } else {
      critThreshold = GlobalSettings.criticalServiceMultiplier;
    }

    return servicesRemaining <= critThreshold;
  }

  /// Determine if an item is getting low
  static bool isGettingLow(Map<String, dynamic> data) {
    final servicesRemaining = InventoryCard.getServicesRemaining(data);

    bool override = data["overrideWarnings"] == true;
    int lowThreshold;
    int critThreshold;

    if (override) {
      lowThreshold =
          (data["gettingLowServices"] ?? GlobalSettings.lowServiceMultiplier)
              as int;
      critThreshold =
          (data["criticalServices"] ?? GlobalSettings.criticalServiceMultiplier)
              as int;
    } else {
      lowThreshold = GlobalSettings.lowServiceMultiplier;
      critThreshold = GlobalSettings.criticalServiceMultiplier;
    }

    return servicesRemaining > critThreshold &&
        servicesRemaining <= lowThreshold;
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Row(
          children: [
            // Status indicator dot and label
            if (isCritical(data)) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Buy Now",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (isGettingLow(data)) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Getting Low",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Item name
            Expanded(
              child: Text(
                data["name"] ?? "",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          "Need: ${requiredQty.toStringAsFixed(1)} $unitType\n"
          "On Hand: ${total.toStringAsFixed(1)} $unitType",
          style: const TextStyle(fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: "Edit Details",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditItemScreen(doc: doc, hideQuantities: true),
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () => _purchaseDialog(context, requiredQty),
              child: const Text("Purchase", style: TextStyle(fontSize: 14)),
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
}
