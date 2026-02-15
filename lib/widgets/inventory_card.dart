import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';
import '../screens/edit_item_screen.dart';
import '../models/inventory_mode.dart';

class InventoryCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final InventoryMode mode;
  final bool showFrequency;
  final bool isAllTab;

  const InventoryCard({
    super.key,
    required this.doc,
    this.isSelected = false,
    this.onSelectionToggle,
    this.mode = InventoryMode.truck,
    this.showFrequency = false,
    this.isAllTab = false,
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
  final _homeCtl = TextEditingController();
  final _homeFocus = FocusNode();
  Timer? _truckDebounce;
  Timer? _homeDebounce;
  double _lastSavedTruckValue = 0.0;
  double _lastSavedHomeValue = 0.0;

  @override
  void initState() {
    super.initState();
    _syncController();
    _truckFocus.addListener(_onTruckFocusChange);
    _homeFocus.addListener(_onHomeFocusChange);
  }

  @override
  void didUpdateWidget(covariant InventoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.id != widget.doc.id ||
        oldWidget.mode != widget.mode ||
        oldWidget.isAllTab != widget.isAllTab) {
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
      final oldHome = (oldData["homeQuantity"] ?? oldData["homeAmount"] ?? 0.0)
          .toDouble();
      final newHome = (newData["homeQuantity"] ?? newData["homeAmount"] ?? 0.0)
          .toDouble();
      if (oldTruck != newTruck && !_truckFocus.hasFocus) {
        _lastSavedTruckValue = newTruck;
        _truckCtl.text = _formatQty(newTruck);
      }
      if (oldHome != newHome && !_homeFocus.hasFocus) {
        _lastSavedHomeValue = newHome;
        _homeCtl.text = _formatQty(newHome);
      }
    }
  }

  void _syncController() {
    final data = widget.doc.data() as Map<String, dynamic>;
    _lastSavedTruckValue = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    _lastSavedHomeValue = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();
    _truckCtl.text = _formatQty(_lastSavedTruckValue);
    _homeCtl.text = _formatQty(_lastSavedHomeValue);
  }

  String _formatQty(double val) {
    return val == val.roundToDouble()
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _truckDebounce?.cancel();
    _homeDebounce?.cancel();
    _truckFocus.removeListener(_onTruckFocusChange);
    _homeFocus.removeListener(_onHomeFocusChange);
    _truckFocus.dispose();
    _homeFocus.dispose();
    _truckCtl.dispose();
    _homeCtl.dispose();
    super.dispose();
  }

  void _onTruckFocusChange() {
    if (!_truckFocus.hasFocus) {
      _truckDebounce?.cancel();
      _saveTruck(_truckCtl.text);
    }
  }

  void _onHomeFocusChange() {
    if (!_homeFocus.hasFocus) {
      _homeDebounce?.cancel();
      _saveHome(_homeCtl.text);
    }
  }

  void _onTruckChanged(String value) {
    _truckDebounce?.cancel();
    _truckDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveTruck(value);
    });
  }

  void _onHomeChanged(String value) {
    _homeDebounce?.cancel();
    _homeDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveHome(value);
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

  void _saveHome(String value) {
    final val = double.tryParse(value);
    if (val != null && val >= 0) {
      // Only proceed if the value actually changed
      if (val != _lastSavedHomeValue) {
        _updateHomeWithVerification(val);
        _lastSavedHomeValue = val;
      }
    }
  }

  void _updateTruckWithVerification(double newValue) async {
    await _service.updateTruckQuantityWithVerification(widget.doc.id, newValue);
  }

  void _updateHomeWithVerification(double newValue) async {
    await _service.updateHomeQuantityWithVerification(widget.doc.id, newValue);
  }

  void _toggleTruckVerified(Map<String, dynamic> data) {
    final isVerified = data["truckVerifiedAt"] != null;
    _service.setTruckVerified(widget.doc.id, !isVerified);
  }

  void _toggleHomeVerified(Map<String, dynamic> data) {
    final isVerified = data["homeVerifiedAt"] != null;
    _service.setHomeVerified(widget.doc.id, !isVerified);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final name = data["name"] ?? "";
    final unitType = data["unitType"] as String?;
    final displayName = unitType != null && unitType.isNotEmpty
        ? "$name \u2013 $unitType"
        : name;
    final truckVerified = data["truckVerifiedAt"] != null;
    final homeVerified = data["homeVerifiedAt"] != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    displayName,
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
            // Frequency label (All tab only)
            if (widget.showFrequency) ...[
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  _frequencyLabel(data),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Quantity sections
            if (widget.isAllTab)
              _buildHorizontalBothSection(
                truckVerified,
                homeVerified,
                () => _toggleTruckVerified(data),
                () => _toggleHomeVerified(data),
              )
            else ...[
              if (widget.mode == InventoryMode.truck ||
                  widget.mode == InventoryMode.both)
                _buildQuantitySection(
                  "Truck",
                  _truckCtl,
                  _truckFocus,
                  _onTruckChanged,
                  truckVerified,
                  () => _toggleTruckVerified(data),
                ),
              if (widget.mode == InventoryMode.home ||
                  widget.mode == InventoryMode.both)
                _buildQuantitySection(
                  "Home",
                  _homeCtl,
                  _homeFocus,
                  _onHomeChanged,
                  homeVerified,
                  () => _toggleHomeVerified(data),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _frequencyLabel(Map<String, dynamic> data) {
    final freq =
        data["inventoryFrequency"] ?? data["checkFrequency"] ?? "perService";
    switch (freq) {
      case "perService":
      case "service":
        return "Per Service";
      case "daily":
        return "Daily";
      case "weekly":
        return "Weekly";
      case "monthly":
        return "Monthly";
      case "quarterly":
        return "Quarterly";
      default:
        return freq.toString();
    }
  }

  Widget _buildHorizontalBothSection(
    bool truckVerified,
    bool homeVerified,
    VoidCallback onToggleTruckVerified,
    VoidCallback onToggleHomeVerified,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: Row(
        children: [
          // Truck section
          _buildCompactQuantity(
            "Truck",
            _truckCtl,
            _truckFocus,
            _onTruckChanged,
            truckVerified,
            onToggleTruckVerified,
          ),
          const SizedBox(width: 16),
          // Home section
          _buildCompactQuantity(
            "Home",
            _homeCtl,
            _homeFocus,
            _onHomeChanged,
            homeVerified,
            onToggleHomeVerified,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQuantity(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    Function(String) onChanged,
    bool isVerified,
    VoidCallback onToggleVerified,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          height: 40,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: Checkbox(
            value: isVerified,
            onChanged: (_) => onToggleVerified(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySection(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    Function(String) onChanged,
    bool isVerified,
    VoidCallback onToggleVerified,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 48,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
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
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              // Verified checkbox inline with quantity
              InkWell(
                onTap: onToggleVerified,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Checkbox(
                        value: isVerified,
                        onChanged: (_) => onToggleVerified(),
                      ),
                    ),
                    const SizedBox(width: 4),
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
        ],
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
