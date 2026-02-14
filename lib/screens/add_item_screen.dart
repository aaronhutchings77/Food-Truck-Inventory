import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final service = InventoryService();

  final nameCtl = TextEditingController();
  final usedPerServiceCtl = TextEditingController();
  final truckQtyCtl = TextEditingController(text: "0");
  final homeQtyCtl = TextEditingController(text: "0");
  final modelCtl = TextEditingController();
  final otherUnitCtl = TextEditingController();

  final overrideTruckTargetCtl = TextEditingController();

  String selectedCategory = "food";
  String selectedFrequency = "perService";
  String selectedUnit = "each";
  bool showOtherUnit = false;
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
  void dispose() {
    nameCtl.dispose();
    usedPerServiceCtl.dispose();
    truckQtyCtl.dispose();
    homeQtyCtl.dispose();
    modelCtl.dispose();
    otherUnitCtl.dispose();
    overrideTruckTargetCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add Item",
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
            _field("Truck Quantity", truckQtyCtl, true),
            _field("Home Quantity", homeQtyCtl, true),
            _field("Model / SKU (Optional)", modelCtl, false),
            const SizedBox(height: 16),
            const Divider(),
            _overrideTruckTargetCheckbox(),
            if (overrideTruckTarget)
              _field("Truck Target (services)", overrideTruckTargetCtl, true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("Save", style: TextStyle(fontSize: 18)),
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

    final truckQty = double.tryParse(truckQtyCtl.text) ?? 0.0;
    final homeQty = double.tryParse(homeQtyCtl.text) ?? 0.0;

    String finalUnit = selectedUnit == "other"
        ? otherUnitCtl.text.trim()
        : selectedUnit;
    if (finalUnit.isEmpty) finalUnit = "each";

    final itemData = <String, dynamic>{
      "name": nameCtl.text.trim(),
      "category": selectedCategory,
      "inventoryFrequency": selectedFrequency,
      "usedPerService": usedPer,
      "truckQuantity": truckQty,
      "homeQuantity": homeQty,
      "unitType": finalUnit,
      "model": modelCtl.text.trim(),
    };

    if (overrideTruckTarget) {
      final val = int.tryParse(overrideTruckTargetCtl.text);
      if (val != null && val >= 0) {
        itemData["overrideTruckTargetServices"] = val;
      }
    }

    await service.addItem(itemData);

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
