import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';
import '../screens/edit_item_screen.dart';

class InventoryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool showCheckButton;
  final bool isOverdue;

  InventoryCard({
    super.key,
    required this.doc,
    this.showCheckButton = false,
    this.isOverdue = false,
  });

  final service = InventoryService();

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
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    double truck = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    double home = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();
    double usedPer = (data["usedPerService"] ?? data["qtyPerService"] ?? 0.0)
        .toDouble();
    String unitType = data["unitType"] ?? "units";
    String model = data["model"] ?? "";

    double total = truck + home;
    double servicesRemaining = usedPer > 0 ? total / usedPer : 0;

    Color status = getWarningColor(data);

    String subtitle = "Qty: ${total.toStringAsFixed(1)} ($unitType)";
    if (usedPer > 0) {
      subtitle += "  |  Used/Service: ${usedPer.toStringAsFixed(1)}";
      subtitle +=
          "\nServices Remaining: ${servicesRemaining.toStringAsFixed(1)}";
    }
    if (model.isNotEmpty) {
      subtitle += "\nModel: $model";
    }

    final lastCheckedAt = data["lastCheckedAt"] as Timestamp?;
    if (showCheckButton) {
      if (lastCheckedAt != null) {
        subtitle += "\nChecked: ${_formatTimestamp(lastCheckedAt)}";
      } else {
        subtitle += "\nNever checked";
      }
    }

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDelete(context);
        return false; // Don't dismiss, let the delete button handle it
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      child: Card(
        color: status.withValues(alpha: 0.1),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: isOverdue
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.blue, width: 3),
              )
            : null,
        child: ListTile(
          title: Text(
            data["name"] ?? "",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCheckButton)
                IconButton(
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: isOverdue ? Colors.blue : Colors.green,
                  ),
                  tooltip: "Mark as Checked",
                  onPressed: () => _markAsChecked(context),
                ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditItemScreen(doc: doc)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                tooltip: "Delete Item",
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAsChecked(BuildContext context) async {
    await service.markAsChecked(doc.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item marked as checked"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else {
      return "${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Item?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await service.deleteItem(doc.id);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
