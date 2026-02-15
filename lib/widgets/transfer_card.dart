import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../screens/edit_item_screen.dart';

class TransferCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String section;
  final double requiredAmount;
  final double truckAmount;
  final double homeAmount;
  final double canMoveNow;
  final double truckAfterTransfer;
  final bool canCoverTomorrow;
  final double stillShort;
  final double stillShortToIdeal;

  TransferCard({
    super.key,
    required this.doc,
    required this.section,
    required this.requiredAmount,
    required this.truckAmount,
    required this.homeAmount,
    required this.canMoveNow,
    required this.truckAfterTransfer,
    required this.canCoverTomorrow,
    required this.stillShort,
    required this.stillShortToIdeal,
  });

  final service = InventoryService();

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final rawName = data["name"] ?? "";
    final unitType = data["unitType"] ?? "units";
    final rawUnitType = data["unitType"] as String?;
    final name = (rawUnitType != null && rawUnitType.isNotEmpty)
        ? "$rawName \u2013 $rawUnitType"
        : rawName;

    final bool isShort = section == "requiredForTomorrow" && !canCoverTomorrow;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isShort ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isShort ? Colors.red.shade900 : null,
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
            // Info lines
            if (section == "requiredForTomorrow") ...[
              _infoLine("Required for 1 Service", requiredAmount, unitType),
              _infoLine("On Truck", truckAmount, unitType),
              _infoLine("At Home", homeAmount, unitType),
              _infoLine("Can Move Now", canMoveNow, unitType),
              if (isShort) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Cannot cover tomorrow's service\n"
                        "Still short: ${_fmt(stillShort)} $unitType",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              _infoLine("Ideal Required", requiredAmount, unitType),
              _infoLine("On Truck", truckAmount, unitType),
              _infoLine("At Home", homeAmount, unitType),
              _infoLine("Can Move Now", canMoveNow, unitType),
              if (stillShortToIdeal > 0)
                _infoLine("Still Short to Ideal", stillShortToIdeal, unitType),
            ],
            const SizedBox(height: 10),
            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (section == "requiredForTomorrow" && !canCoverTomorrow) ...[
                  ElevatedButton.icon(
                    onPressed: () => _addFromStore(context, "home"),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text("Add from Store \u2192 Home"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addFromStore(context, "truck"),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text("Add from Store \u2192 Truck"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (canMoveNow > 0)
                    ElevatedButton.icon(
                      onPressed: () => _moveFromHome(context),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text("Move ${_fmt(canMoveNow)} from Home"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ] else
                  ElevatedButton.icon(
                    onPressed: () => _moveFromHome(context),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text("Move ${_fmt(canMoveNow)} from Home"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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

  Widget _infoLine(String label, double value, String unitType) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        "$label: ${_fmt(value)} $unitType",
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Future<void> _moveFromHome(BuildContext context) async {
    final moveAmount = math.min(homeAmount, requiredAmount - truckAmount);
    final qtyController = TextEditingController(text: _fmt(moveAmount));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Move from Home to Truck"),
        content: TextField(
          controller: qtyController,
          decoration: const InputDecoration(labelText: "Quantity to move"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Move"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final qty = double.tryParse(qtyController.text) ?? 0;
      if (qty > 0) {
        final data = doc.data() as Map<String, dynamic>;
        final currentTruck = (data["truckQuantity"] ?? 0.0).toDouble();
        final currentHome = (data["homeQuantity"] ?? 0.0).toDouble();
        final actualMove = math.min(qty, currentHome);
        await service.updateField(
          doc.id,
          "truckQuantity",
          currentTruck + actualMove,
        );
        await service.updateField(
          doc.id,
          "homeQuantity",
          currentHome - actualMove,
        );
      }
    }
  }

  Future<void> _addFromStore(BuildContext context, String destination) async {
    final qtyController = TextEditingController(
      text: _fmt(stillShort > 0 ? stillShort : requiredAmount - truckAmount),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
