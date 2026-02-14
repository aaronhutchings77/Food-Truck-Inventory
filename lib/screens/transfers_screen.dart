import 'dart:math' as math;
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

                  final List<_TransferItem> requiredForTomorrow = [];
                  final List<_TransferItem> belowIdealTarget = [];

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final result = _classifyItem(data);
                    if (result == null) continue;

                    final item = _TransferItem(
                      doc: doc,
                      section: result.section,
                      requiredAmount: result.requiredAmount,
                      truckAmount: result.truckAmount,
                      homeAmount: result.homeAmount,
                      canMoveNow: result.canMoveNow,
                      truckAfterTransfer: result.truckAfterTransfer,
                      stillShort: result.stillShort,
                      canCoverTomorrow: result.canCoverTomorrow,
                      stillShortToIdeal: result.stillShortToIdeal,
                    );

                    if (result.section == "requiredForTomorrow") {
                      requiredForTomorrow.add(item);
                    } else {
                      belowIdealTarget.add(item);
                    }
                  }

                  // Sort items alphabetically within each section
                  int alphabetical(_TransferItem a, _TransferItem b) {
                    final aName =
                        (a.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    final bName =
                        (b.doc.data() as Map<String, dynamic>)["name"] ?? "";
                    return aName.toLowerCase().compareTo(bName.toLowerCase());
                  }

                  requiredForTomorrow.sort(alphabetical);
                  belowIdealTarget.sort(alphabetical);

                  if (requiredForTomorrow.isEmpty && belowIdealTarget.isEmpty) {
                    return const Center(
                      child: Text(
                        "Truck is fully stocked!",
                        style: TextStyle(fontSize: 18),
                      ),
                    );
                  }

                  return ListView(
                    children: [
                      _buildSection(
                        "Required for Tomorrow",
                        Icons.warning_amber_rounded,
                        Colors.red,
                        requiredForTomorrow,
                        initiallyExpanded: true,
                      ),
                      _buildSection(
                        "Below Ideal Target",
                        Icons.trending_down,
                        Colors.orange,
                        belowIdealTarget,
                        initiallyExpanded: false,
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

  /// Classify an item into a transfer section.
  /// Returns null if no transfer is needed.
  _TransferResult? _classifyItem(Map<String, dynamic> data) {
    double usedPer = (data["usedPerService"] ?? data["qtyPerService"] ?? 0.0)
        .toDouble();
    double truck = (data["truckQuantity"] ?? data["truckAmount"] ?? 0.0)
        .toDouble();
    double home = (data["homeQuantity"] ?? data["homeAmount"] ?? 0.0)
        .toDouble();

    if (usedPer <= 0) return null;

    // Explicit null check: only null falls back to global. 0 is a valid override.
    final dynamic rawOverride = data["overrideTruckTargetServices"];
    final int effectiveTruckTarget = rawOverride != null
        ? (rawOverride as num).toInt()
        : GlobalSettings.truckTargetServices;

    // If override is 0, this is a home-only item — never needs transfer
    if (effectiveTruckTarget == 0) return null;

    double requiredForOneService = usedPer * 1;
    double requiredForIdeal = usedPer * effectiveTruckTarget;

    // Section 1: Required for Tomorrow — truck < requiredForOneService
    if (truck < requiredForOneService) {
      double canMoveNow = math.min(home, requiredForOneService - truck);
      double truckAfterTransfer = truck + canMoveNow;
      bool canCoverTomorrow = truckAfterTransfer >= requiredForOneService;
      double stillShort = canCoverTomorrow
          ? 0
          : requiredForOneService - truckAfterTransfer;

      return _TransferResult(
        section: "requiredForTomorrow",
        requiredAmount: requiredForOneService,
        truckAmount: truck,
        homeAmount: home,
        canMoveNow: canMoveNow,
        truckAfterTransfer: truckAfterTransfer,
        canCoverTomorrow: canCoverTomorrow,
        stillShort: stillShort,
        stillShortToIdeal: 0,
      );
    }

    // Section 2: Below Ideal Target — truck >= 1 service but < ideal
    if (truck < requiredForIdeal) {
      double canMoveNow = math.min(home, requiredForIdeal - truck);
      double truckAfterTransfer = truck + canMoveNow;
      double stillShortToIdeal = math.max(0, requiredForIdeal - (truck + home));

      return _TransferResult(
        section: "belowIdealTarget",
        requiredAmount: requiredForIdeal,
        truckAmount: truck,
        homeAmount: home,
        canMoveNow: canMoveNow,
        truckAfterTransfer: truckAfterTransfer,
        canCoverTomorrow: true,
        stillShort: 0,
        stillShortToIdeal: stillShortToIdeal,
      );
    }

    // Truck is at or above ideal — no transfer needed
    return null;
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<_TransferItem> items, {
    required bool initiallyExpanded,
  }) {
    if (items.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(
          "$title (${items.length})",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: initiallyExpanded,
        children: items
            .map(
              (item) => TransferCard(
                doc: item.doc,
                section: item.section,
                requiredAmount: item.requiredAmount,
                truckAmount: item.truckAmount,
                homeAmount: item.homeAmount,
                canMoveNow: item.canMoveNow,
                truckAfterTransfer: item.truckAfterTransfer,
                canCoverTomorrow: item.canCoverTomorrow,
                stillShort: item.stillShort,
                stillShortToIdeal: item.stillShortToIdeal,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TransferResult {
  final String section;
  final double requiredAmount;
  final double truckAmount;
  final double homeAmount;
  final double canMoveNow;
  final double truckAfterTransfer;
  final bool canCoverTomorrow;
  final double stillShort;
  final double stillShortToIdeal;

  _TransferResult({
    required this.section,
    required this.requiredAmount,
    required this.truckAmount,
    required this.homeAmount,
    required this.canMoveNow,
    required this.truckAfterTransfer,
    required this.canCoverTomorrow,
    required this.stillShort,
    required this.stillShortToIdeal,
  });
}

class _TransferItem {
  final QueryDocumentSnapshot doc;
  final String section;
  final double requiredAmount;
  final double truckAmount;
  final double homeAmount;
  final double canMoveNow;
  final double truckAfterTransfer;
  final bool canCoverTomorrow;
  final double stillShort;
  final double stillShortToIdeal;

  _TransferItem({
    required this.doc,
    required this.section,
    required this.requiredAmount,
    required this.truckAmount,
    required this.homeAmount,
    required this.canMoveNow,
    required this.truckAfterTransfer,
    required this.canCoverTomorrow,
    required this.stillShort,
    required this.stillShortToIdeal,
  });
}
