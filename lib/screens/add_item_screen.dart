import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

class AddItemScreen extends StatelessWidget {
  AddItemScreen({super.key});

  final service = InventoryService();

  final name = TextEditingController();
  final per = TextEditingController();
  final critical = TextEditingController();
  final low = TextEditingController();
  final buffer = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _field("Name", name, false),
            _field("Amount Per Service", per, true),
            _field("Critical Services", critical, true),
            _field("Low Warning Services", low, true),
            _field("Buffer Services", buffer, true),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () async {
                  await service.addItem({
                    "name": name.text,
                    "amountPerService": double.parse(per.text),
                    "truckAmount": 0.0,
                    "homeAmount": 0.0,
                    "criticalServices": int.parse(critical.text),
                    "lowWarningServices": int.parse(low.text),
                    "desiredBufferServices": int.parse(buffer.text),
                  });

                  Navigator.pop(context);
                },
                child: const Text("Save"))
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
}
