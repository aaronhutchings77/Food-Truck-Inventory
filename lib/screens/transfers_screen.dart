import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/transfer_card.dart';
import '../settings/global_settings.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterBySearch(
    List<QueryDocumentSnapshot> docs,
  ) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data["name"] ?? "").toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: GlobalSettings.settingsStream,
      builder: (context, settingsSnapshot) {
        if (settingsSnapshot.hasData) {
          GlobalSettings.initialize(settingsSnapshot.data!);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: "Search items...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                            setState(() {});
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("items")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = _filterBySearch(snapshot.data!.docs);

                  final List<_TransferItem> moveFromHome = [];
                  final List<_TransferItem> buyAndMove = [];
                  final List<_TransferItem> buyOnly = [];

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final result = _classifyItem(data);
                    if (result == null) continue;

                    final item = _TransferItem(
                      doc: doc,
                      transferAmount: result.transferAmount,
                      truckRequired: result.truckRequired,
                      type: result.type,
                    );

                    switch (result.type) {
                      case "move":
                        moveFromHome.add(item);
                        break;
                      case "buyAndMove":
                        buyAndMove.add(item);
                        break;
                      case "buyOnly":
                        buyOnly.add(item);
                        break;
                    }
                  }

                  // Sort items alphabetically within each transfer section
                  moveFromHome.sort((a, b) {
                    final aName =
                        (a.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    final bName =
                        (b.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    return aName.toLowerCase().compareTo(bName.toLowerCase());
                  });

                  buyAndMove.sort((a, b) {
                    final aName =
                        (a.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    final bName =
                        (b.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    return aName.toLowerCase().compareTo(bName.toLowerCase());
                  });

                  buyOnly.sort((a, b) {
                    final aName =
                        (a.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    final bName =
                        (b.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    return aName.toLowerCase().compareTo(bName.toLowerCase());
                  });

                  if (moveFromHome.isEmpty &&
                      buyAndMove.isEmpty &&
                      buyOnly.isEmpty) {
                    return const Center(
                      child: Text(
                        "Truck is fully stocked!",
                        style: TextStyle(fontSize: 18),
                      ),
                    );
                  }

                  return ListView(
                    children: [
                      _collapsibleSection(
                        "Move From Home",
                        Icons.home,
                        Colors.blue,
                        moveFromHome,
                      ),
                      _collapsibleSection(
                        "Buy + Move",
                        Icons.shopping_cart,
                        Colors.orange,
                        buyAndMove,
                      ),
                      _collapsibleSection(
                        "Buy Only",
                        Icons.store,
                        Colors.green,
                        buyOnly,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Classify an item into transfer type based on the transfer logic.
  _TransferResult? _classifyItem(Map<String, dynamic> data) {
    double usedPer = (data["usedPerService"] ?? data["qtyPerService"] ?? 0.0)
        .toDouble();
    double truck = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    double home = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();

    if (usedPer <= 0) return null;

    // effectiveTruckTarget
    int? override = data["overrideTruckTargetServices"] as int?;
    int effectiveTruckTarget = override ?? GlobalSettings.truckTargetServices;

    double truckRequired = usedPer * effectiveTruckTarget;

    // If truck already has enough, no transfer needed
    if (truck >= truckRequired) return null;

    double transferAmount = truckRequired - truck;

    if (home >= transferAmount) {
      // Can move from home
      return _TransferResult(
        type: "move",
        transferAmount: transferAmount,
        truckRequired: truckRequired,
      );
    } else {
      // Not enough at home — need to buy
      // Check if there's also a shopping need (totalAvailable < overallRequired)
      double totalAvailable = truck + home;
      double overallRequired = usedPer * GlobalSettings.targetServices;

      if (totalAvailable < overallRequired) {
        // Need to buy AND transfer
        return _TransferResult(
          type: "buyAndMove",
          transferAmount: transferAmount,
          truckRequired: truckRequired,
        );
      } else {
        // Have enough overall but not on truck, and not enough at home to move
        // Still need to buy for the truck specifically
        return _TransferResult(
          type: "buyOnly",
          transferAmount: transferAmount,
          truckRequired: truckRequired,
        );
      }
    }
  }

  Widget _collapsibleSection(
    String title,
    IconData icon,
    Color color,
    List<_TransferItem> items,
  ) {
    if (items.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(
          "$title (${items.length})",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: false,
        children: items
            .map(
              (item) => TransferCard(
                doc: item.doc,
                transferAmount: item.transferAmount,
                truckRequired: item.truckRequired,
                transferType: item.type,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TransferResult {
  final String type;
  final double transferAmount;
  final double truckRequired;

  _TransferResult({
    required this.type,
    required this.transferAmount,
    required this.truckRequired,
  });
}

class _TransferItem {
  final QueryDocumentSnapshot doc;
  final double transferAmount;
  final double truckRequired;
  final String type;

  _TransferItem({
    required this.doc,
    required this.transferAmount,
    required this.truckRequired,
    required this.type,
  });
}
