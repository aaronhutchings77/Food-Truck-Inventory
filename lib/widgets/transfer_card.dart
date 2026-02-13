import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../screens/edit_item_screen.dart';

class TransferCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final double transferAmount;
  final double truckRequired;
  final String transferType; // "move", "buyAndMove", "buyOnly"

  TransferCard({
    super.key,
    required this.doc,
    required this.transferAmount,
    required this.truckRequired,
    required this.transferType,
  });

  final service = InventoryService();

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data["name"] ?? "";
    final unitType = data["unitType"] ?? "units";
    double truck = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    double home = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
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
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Truck: ${truck.toStringAsFixed(1)} $unitType\n"
              "Home: ${home.toStringAsFixed(1)} $unitType\n"
              "Required on Truck: ${truckRequired.toStringAsFixed(1)} $unitType\n"
              "Move: ${transferAmount.toStringAsFixed(1)} $unitType",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (transferType == "move")
                  ElevatedButton.icon(
                    onPressed: () => _moveFromHome(context, transferAmount),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text("Move from Home"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (transferType == "buyAndMove") ...[
                  ElevatedButton.icon(
                    onPressed: () => _addFromStore(context, "truck"),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text("Add from Store to Truck"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addFromStore(context, "home"),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text("Add from Store to Home"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                if (transferType == "buyOnly")
                  ElevatedButton.icon(
                    onPressed: () => _addFromStore(context, "truck"),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text("Add from Store to Truck"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveFromHome(BuildContext context, double amount) async {
    final qtyController = TextEditingController(
      text: amount.toStringAsFixed(1),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Move from Home to Truck"),
        content: TextField(
          controller: qtyController,
          decoration: const InputDecoration(labelText: "Quantity to move"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Move"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final qty = double.tryParse(qtyController.text) ?? 0;
      if (qty > 0) {
        await service.updateField(
          doc.id,
          "truckQuantity",
          ((doc.data() as Map<String, dynamic>)["truckQuantity"] ?? 0.0)
                  .toDouble() +
              qty,
        );
        await service.updateField(
          doc.id,
          "homeQuantity",
          ((doc.data() as Map<String, dynamic>)["homeQuantity"] ?? 0.0)
                  .toDouble() -
              qty,
        );
      }
    }
  }

  Future<void> _addFromStore(BuildContext context, String destination) async {
    final qtyController = TextEditingController(
      text: transferAmount.toStringAsFixed(1),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "Add from Store to ${destination == "truck" ? "Truck" : "Home"}",
        ),
        content: TextField(
          controller: qtyController,
          decoration: const InputDecoration(labelText: "Quantity purchased"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final qty = double.tryParse(qtyController.text) ?? 0;
      if (qty > 0) {
        final truckAdd = destination == "truck" ? qty : 0.0;
        await service.addPurchase(doc.id, qty, truckAdd);
      }
    }
  }
}
