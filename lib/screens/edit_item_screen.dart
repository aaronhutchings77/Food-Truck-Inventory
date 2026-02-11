import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';

class EditItemScreen extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const EditItemScreen({super.key, required this.doc});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
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
    'case',
    'dozen',
    'gallon',
    'bottle',
    'carton',
    'box',
    'bag',
    'pack',
    'container',
    'tray',
    'each',
    'Other...'
  ];

  @override
  void initState() {
    super.initState();
    _loadItemData();
  }

  void _loadItemData() {
    final data = widget.doc.data() as Map<String, dynamic>;
    
    name.text = data["name"] ?? "";
    per.text = (data["qtyPerService"] ?? 0).toString();
    low.text = (data["gettingLow"] ?? 0).toString();
    purchase.text = (data["needToPurchase"] ?? 0).toString();
    model.text = data["model"] ?? "";
    selectedCategory = data["category"] ?? "food";
    
    String unitType = data["unitType"] ?? "each";
    if (unitOptions.contains(unitType)) {
      selectedUnit = unitType;
      showOtherUnit = false;
    } else {
      selectedUnit = "Other...";
      showOtherUnit = true;
      otherUnitController.text = unitType;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _field("Item Name", name, false),
            _categoryDropdown(),
            _unitDropdown(),
            if (showOtherUnit) _field("Custom Unit", otherUnitController, false),
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

                await service.updateItem(widget.doc.id, {
                  "name": name.text,
                  "category": selectedCategory,
                  "qtyPerService": double.parse(per.text),
                  "gettingLow": double.parse(low.text),
                  "needToPurchase": double.parse(purchase.text),
                  "unitType": finalUnit,
                  "model": model.text,
                });

                Navigator.pop(context);
              },
              child: const Text("Save Changes"),
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
        value: selectedCategory,
        decoration: const InputDecoration(labelText: "Category"),
        items: const [
          DropdownMenuItem(value: "food", child: Text("Food")),
          DropdownMenuItem(value: "service", child: Text("Service")),
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
        value: selectedUnit,
        decoration: const InputDecoration(labelText: "Unit Type"),
        items: unitOptions.map((String unit) {
          return DropdownMenuItem<String>(
            value: unit,
            child: Text(unit),
          );
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
}
