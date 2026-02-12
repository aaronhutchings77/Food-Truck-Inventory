import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';
import '../screens/edit_item_screen.dart';

class InventoryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  InventoryCard({super.key, required this.doc});

  final service = InventoryService();

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    double truck = data["truckAmount"] ?? 0.0;
    double home = data["homeAmount"] ?? 0.0;
    double qtyPerService = data["qtyPerService"] ?? 1.0;
    String unitType = data["unitType"] ?? "units";
    String model = data["model"] ?? "";

    double total = truck + home;
    double servicesRemaining = qtyPerService > 0 ? total / qtyPerService : 0;

    Color status = Colors.green;

    if (total <= (data["needToPurchase"] ?? 0) ||
        servicesRemaining < GlobalSettings.servicesTarget) {
      status = Colors.red;
    } else if (total <= (data["gettingLow"] ?? 0)) {
      status = Colors.orange;
    }

    String subtitle = "Current: $total ($unitType)";
    if (qtyPerService > 0) {
      subtitle +=
          "\nServices Remaining: ${servicesRemaining.toStringAsFixed(1)}";
    }
    if (model.isNotEmpty) {
      subtitle += "\nModel: $model";
    }

    return Card(
      color: status.withOpacity(0.1),
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditItemScreen(doc: doc)),
          );
        },
        child: ListTile(
          title: Text(data["name"]),
          subtitle: Text(subtitle),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditItemScreen(doc: doc),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
