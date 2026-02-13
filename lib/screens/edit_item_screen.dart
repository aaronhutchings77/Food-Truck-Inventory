import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';

class EditItemScreen extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final bool hideQuantities;
  const EditItemScreen({
    super.key,
    required this.doc,
    this.hideQuantities = false,
  });

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final service = InventoryService();

  final nameCtl = TextEditingController();
  final usedPerServiceCtl = TextEditingController();
  final truckQtyCtl = TextEditingController();
  final homeQtyCtl = TextEditingController();
  final modelCtl = TextEditingController();
  final otherUnitCtl = TextEditingController();
  final gettingLowServicesCtl = TextEditingController();
  final criticalServicesCtl = TextEditingController();
  final overrideTruckTargetCtl = TextEditingController();

  String selectedCategory = "food";
  String selectedFrequency = "perService";
  String selectedUnit = "each";
  bool showOtherUnit = false;
  bool overrideWarnings = false;
  bool overrideTruckTarget = false;

  final List<String> unitOptions = [
    'each',
    'case',
    'box',
    'carton',
    'dozen',
    'gallon',
    'bag',
    'bottle',
    'pack',
    'tray',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadItemData();
  }

  @override
  void dispose() {
    nameCtl.dispose();
    usedPerServiceCtl.dispose();
    truckQtyCtl.dispose();
    homeQtyCtl.dispose();
    modelCtl.dispose();
    otherUnitCtl.dispose();
    gettingLowServicesCtl.dispose();
    criticalServicesCtl.dispose();
    overrideTruckTargetCtl.dispose();
    super.dispose();
  }

  void _loadItemData() {
    final data = widget.doc.data() as Map<String, dynamic>;

    nameCtl.text = data["name"] ?? "";
    usedPerServiceCtl.text =
        (data["usedPerService"] ?? data["qtyPerService"] ?? 0).toString();
    truckQtyCtl.text = (data["truckQuantity"] ?? data["truckAmount"] ?? 0)
        .toString();
    homeQtyCtl.text = (data["homeQuantity"] ?? data["homeAmount"] ?? 0)
        .toString();
    modelCtl.text = data["model"] ?? "";

    selectedCategory = data["category"] ?? "food";
    if (selectedCategory == "service") selectedCategory = "supplies";

    String freq =
        data["inventoryFrequency"] ?? data["checkFrequency"] ?? "perService";
    if (freq == "service") freq = "perService";
    selectedFrequency = freq;

    overrideWarnings = data["overrideWarnings"] ?? false;
    gettingLowServicesCtl.text = (data["gettingLowServices"] ?? 0).toString();
    criticalServicesCtl.text = (data["criticalServices"] ?? 0).toString();

    overrideTruckTarget = data["overrideTruckTargetServices"] != null;
    if (overrideTruckTarget) {
      overrideTruckTargetCtl.text = data["overrideTruckTargetServices"]
          .toString();
    }

    String unitType = data["unitType"] ?? "each";
    if (unitOptions.contains(unitType)) {
      selectedUnit = unitType;
      showOtherUnit = false;
    } else {
      selectedUnit = "other";
      showOtherUnit = true;
      otherUnitCtl.text = unitType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Edit Item",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _field("Item Name", nameCtl, false),
            _categoryDropdown(),
            _frequencyDropdown(),
            _unitDropdown(),
            if (showOtherUnit) _field("Custom Unit", otherUnitCtl, false),
            _field("Used Per Service", usedPerServiceCtl, true),
            if (!widget.hideQuantities)
              _field("Truck Quantity", truckQtyCtl, true),
            if (!widget.hideQuantities)
              _field("Home Quantity", homeQtyCtl, true),
            _field("Model / SKU (Optional)", modelCtl, false),
            const SizedBox(height: 16),
            const Divider(),
            _overrideTruckTargetCheckbox(),
            if (overrideTruckTarget)
              _field("Truck Target (services)", overrideTruckTargetCtl, true),
            const SizedBox(height: 8),
            const Divider(),
            _overrideCheckbox(),
            if (overrideWarnings) ...[
              _field("Getting Low (services)", gettingLowServicesCtl, true),
              _field("Need to Purchase (services)", criticalServicesCtl, true),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("Save Changes", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (nameCtl.text.trim().isEmpty) {
      _showError("Item name is required");
      return;
    }

    final usedPer = double.tryParse(usedPerServiceCtl.text);
    if (usedPer == null || usedPer < 0) {
      _showError("Used Per Service must be a valid number >= 0");
      return;
    }

    String finalUnit = selectedUnit == "other"
        ? otherUnitCtl.text.trim()
        : selectedUnit;
    if (finalUnit.isEmpty) finalUnit = "each";

    final updates = <String, dynamic>{
      "name": nameCtl.text.trim(),
      "category": selectedCategory,
      "inventoryFrequency": selectedFrequency,
      "usedPerService": usedPer,
      "unitType": finalUnit,
      "model": modelCtl.text.trim(),
      "overrideWarnings": overrideWarnings,
    };

    if (!widget.hideQuantities) {
      updates["truckQuantity"] = double.tryParse(truckQtyCtl.text) ?? 0.0;
      updates["homeQuantity"] = double.tryParse(homeQtyCtl.text) ?? 0.0;
    }

    if (overrideWarnings) {
      updates["gettingLowServices"] =
          int.tryParse(gettingLowServicesCtl.text) ?? 0;
      updates["criticalServices"] = int.tryParse(criticalServicesCtl.text) ?? 0;
    }

    if (overrideTruckTarget) {
      final val = int.tryParse(overrideTruckTargetCtl.text);
      if (val != null && val > 0) {
        updates["overrideTruckTargetServices"] = val;
      } else {
        updates["overrideTruckTargetServices"] = FieldValue.delete();
      }
    } else {
      updates["overrideTruckTargetServices"] = FieldValue.delete();
    }

    await service.updateItem(widget.doc.id, updates);
    if (mounted) Navigator.pop(context);
  }

  Widget _field(String label, TextEditingController controller, bool numeric) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: const TextStyle(fontSize: 16),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
      ),
    );
  }

  Widget _categoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selectedCategory,
        decoration: const InputDecoration(
          labelText: "Category",
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        items: const [
          DropdownMenuItem(value: "food", child: Text("Food")),
          DropdownMenuItem(value: "supplies", child: Text("Supplies")),
          DropdownMenuItem(value: "equipment", child: Text("Equipment")),
        ],
        onChanged: (value) => setState(() => selectedCategory = value!),
      ),
    );
  }

  Widget _frequencyDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selectedFrequency,
        decoration: const InputDecoration(
          labelText: "Inventory Frequency",
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        items: const [
          DropdownMenuItem(value: "perService", child: Text("Per Service")),
          DropdownMenuItem(value: "daily", child: Text("Daily")),
          DropdownMenuItem(value: "weekly", child: Text("Weekly")),
          DropdownMenuItem(value: "monthly", child: Text("Monthly")),
          DropdownMenuItem(value: "quarterly", child: Text("Quarterly")),
        ],
        onChanged: (value) => setState(() => selectedFrequency = value!),
      ),
    );
  }

  Widget _unitDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selectedUnit,
        decoration: const InputDecoration(
          labelText: "Unit Type",
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        items: unitOptions.map((String unit) {
          return DropdownMenuItem<String>(value: unit, child: Text(unit));
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedUnit = value!;
            showOtherUnit = (value == "other");
          });
        },
      ),
    );
  }

  Widget _overrideCheckbox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        title: const Text(
          "Override Default Warnings",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text("Set custom warning thresholds for this item"),
        value: overrideWarnings,
        onChanged: (value) {
          setState(() {
            overrideWarnings = value ?? false;
          });
        },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _overrideTruckTargetCheckbox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        title: const Text(
          "Override Truck Target",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text("Set a custom truck target for this item"),
        value: overrideTruckTarget,
        onChanged: (value) {
          setState(() {
            overrideTruckTarget = value ?? false;
          });
        },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
