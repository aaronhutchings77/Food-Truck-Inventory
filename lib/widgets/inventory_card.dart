import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';
import '../screens/edit_item_screen.dart';

class InventoryCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  const InventoryCard({
    super.key,
    required this.doc,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  /// Calculate services remaining for an item document.
  static double getServicesRemaining(Map<String, dynamic> data) {
    double truck = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    double home = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();
    double usedPer = (data["usedPerService"] ?? data["qtyPerService"] ?? 0.0)
        .toDouble();
    double total = truck + home;
    return usedPer > 0 ? total / usedPer : double.infinity;
  }

  /// Determine warning color for an item.
  static Color getWarningColor(Map<String, dynamic> data) {
    double servicesRemaining = getServicesRemaining(data);
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

    if (servicesRemaining <= critThreshold) return Colors.red;
    if (servicesRemaining <= lowThreshold) return Colors.orange;
    return Colors.green;
  }

  /// Check if item is in warning state (getting low or critical).
  static bool isWarning(Map<String, dynamic> data) {
    return getWarningColor(data) != Colors.green;
  }

  @override
  State<InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<InventoryCard> {
  final _service = InventoryService();
  final _truckCtl = TextEditingController();
  final _truckFocus = FocusNode();
  Timer? _truckDebounce;
  double _lastSavedTruckValue = 0.0;

  @override
  void initState() {
    super.initState();
    _syncController();
    _truckFocus.addListener(_onTruckFocusChange);
  }

  @override
  void didUpdateWidget(covariant InventoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.id != widget.doc.id) {
      _syncController();
    } else {
      final oldData = oldWidget.doc.data() as Map<String, dynamic>;
      final newData = widget.doc.data() as Map<String, dynamic>;
      final oldTruck =
          (oldData["truckQuantity"] ?? oldData["truckAmount"] ?? 0.0)
              .toDouble();
      final newTruck =
          (newData["truckQuantity"] ?? newData["truckAmount"] ?? 0.0)
              .toDouble();
      if (oldTruck != newTruck && !_truckFocus.hasFocus) {
        _lastSavedTruckValue = newTruck;
        _truckCtl.text = _formatQty(newTruck);
      }
    }
  }

  void _syncController() {
    final data = widget.doc.data() as Map<String, dynamic>;
    _lastSavedTruckValue = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    _truckCtl.text = _formatQty(_lastSavedTruckValue);
  }

  String _formatQty(double val) {
    return val == val.roundToDouble()
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _truckDebounce?.cancel();
    _truckFocus.removeListener(_onTruckFocusChange);
    _truckFocus.dispose();
    _truckCtl.dispose();
    super.dispose();
  }

  void _onTruckFocusChange() {
    if (!_truckFocus.hasFocus) {
      _truckDebounce?.cancel();
      _saveTruck(_truckCtl.text);
    }
  }

  void _onTruckChanged(String value) {
    _truckDebounce?.cancel();
    _truckDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveTruck(value);
    });
  }

  void _saveTruck(String value) {
    final val = double.tryParse(value);
    if (val != null && val >= 0) {
      // Only proceed if the value actually changed
      if (val != _lastSavedTruckValue) {
        _updateTruckWithVerification(val);
        _lastSavedTruckValue = val;
      }
    }
  }

  void _updateTruckWithVerification(double newValue) async {
    await _service.updateTruckQuantityWithVerification(widget.doc.id, newValue);
  }

  void _toggleTruckVerified(Map<String, dynamic> data) {
    final isVerified = data["truckVerifiedAt"] != null;
    _service.setTruckVerified(widget.doc.id, !isVerified);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final name = data["name"] ?? "";
    final isVerified = data["truckVerifiedAt"] != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Selection checkbox + Item Name + Edit/Delete buttons
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onSelectionToggle?.call(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Edit button
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: "Edit Details",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditItemScreen(doc: widget.doc),
                        ),
                      );
                    },
                  ),
                ),
                // Delete button
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                    ),
                    tooltip: "Delete",
                    onPressed: () => _confirmDelete(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Truck label + numeric input + Verified
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Truck",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 120,
                    height: 48,
                    child: TextField(
                      controller: _truckCtl,
                      focusNode: _truckFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onChanged: _onTruckChanged,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Verified checkbox
                  InkWell(
                    onTap: () => _toggleTruckVerified(data),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Checkbox(
                            value: isVerified,
                            onChanged: (_) => _toggleTruckVerified(data),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Verified",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: isVerified
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Item?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _service.deleteItem(widget.doc.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
