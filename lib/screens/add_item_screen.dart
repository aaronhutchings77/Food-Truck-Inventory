import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final service = InventoryService();

  final name = TextEditingController();
  final per = TextEditingController();
  final low = TextEditingController();
  final purchase = TextEditingController();
  final model = TextEditingController();
  String selectedCategory = "food";
  String selectedUnit = "each";
  bool showOtherUnit = false;
  final otherUnitController = TextEditingController();

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _field("Item Name", name, false),
            _categoryDropdown(),
            _unitDropdown(),
            if (showOtherUnit)
              _field("Custom Unit", otherUnitController, false),
            _field("Used Each Service (QTY)", per, true),
            _field("Getting Low (QTY)", low, true),
            _field("Need to Purchase (QTY)", purchase, true),
            _field("Model / SKU (Optional)", model, false),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (!_validateFields()) return;

                String finalUnit = selectedUnit == "Other..."
                    ? otherUnitController.text
                    : selectedUnit;

                await service.addItem({
                  "name": name.text,
                  "category": selectedCategory,
                  "qtyPerService": double.parse(per.text),
                  "truckAmount": 0.0,
                  "homeAmount": 0.0,
                  "gettingLow": double.parse(low.text),
                  "needToPurchase": double.parse(purchase.text),
                  "unitType": finalUnit,
                  "model": model.text,
                });

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, bool numeric) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
      ),
    );
  }

  Widget _categoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: selectedCategory,
        decoration: const InputDecoration(labelText: "Category"),
        items: const [
          DropdownMenuItem(value: "food", child: Text("Food")),
          DropdownMenuItem(value: "supplies", child: Text("Supplies")),
          DropdownMenuItem(value: "equipment", child: Text("Equipment")),
        ],
        onChanged: (value) {
          setState(() {
            selectedCategory = value!;
          });
        },
      ),
    );
  }

  Widget _unitDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: selectedUnit,
        decoration: const InputDecoration(labelText: "Unit Type"),
        items: unitOptions.map((String unit) {
          return DropdownMenuItem<String>(value: unit, child: Text(unit));
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedUnit = value!;
            showOtherUnit = (value == "Other...");
          });
        },
      ),
    );
  }

  bool _validateFields() {
    try {
      double perValue = double.parse(per.text);
      double lowValue = double.parse(low.text);
      double purchaseValue = double.parse(purchase.text);

      if (perValue < 0) {
        _showError("Qty per service must be ≥ 0");
        return false;
      }
      if (purchaseValue < 0) {
        _showError("Need to Purchase must be ≥ 0");
        return false;
      }
      if (lowValue < purchaseValue) {
        _showError("Getting Low must be ≥ Need to Purchase");
        return false;
      }
      return true;
    } catch (e) {
      _showError("Please enter valid numbers for quantity fields");
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
