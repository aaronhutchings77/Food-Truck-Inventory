import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/shopping_card.dart';
import '../widgets/inventory_card.dart';
import '../settings/global_settings.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allDocs = [];
  List<QueryDocumentSnapshot> _filteredDocs = [];

  /// Determine if an item is critical (needs to buy now)
  bool _isCritical(Map<String, dynamic> data) {
    final servicesRemaining = InventoryCard.getServicesRemaining(data);

    bool override = data["overrideWarnings"] == true;
    int critThreshold;

    if (override) {
      critThreshold =
          (data["criticalServices"] ?? GlobalSettings.criticalServiceMultiplier)
              as int;
    } else {
      critThreshold = GlobalSettings.criticalServiceMultiplier;
    }

    return servicesRemaining <= critThreshold;
  }

  /// Determine if an item is getting low
  bool _isGettingLow(Map<String, dynamic> data) {
    final servicesRemaining = InventoryCard.getServicesRemaining(data);

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

    return servicesRemaining > critThreshold &&
        servicesRemaining <= lowThreshold;
  }

  /// Check if item needs shopping (either critical or getting low)
  bool _needsShopping(Map<String, dynamic> data) {
    return _isCritical(data) || _isGettingLow(data);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDocs = _allDocs;
      } else {
        _filteredDocs = _allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data["name"] ?? "").toLowerCase();
          final model = (data["model"] ?? "").toLowerCase();
          final unitType = (data["unitType"] ?? "").toLowerCase();
          return name.contains(query) ||
              model.contains(query) ||
              unitType.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with target info
        StreamBuilder<Map<String, int>>(
          stream: GlobalSettings.settingsStream,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? {};
            final target =
                settings["targetServices"] ?? GlobalSettings.targetServices;

            if (snapshot.hasData) GlobalSettings.initialize(snapshot.data!);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Text(
                    "Shopping for $target overall services",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
            stream: FirebaseFirestore.instance.collection("items").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              _allDocs = snapshot.data!.docs;
              final docsToUse = _searchController.text.isEmpty
                  ? _allDocs
                  : _filteredDocs;

              // Shopping list: items that are critical or getting low
              final needsShopping = docsToUse.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _needsShopping(data);
              }).toList();

              if (needsShopping.isEmpty) {
                return const Center(
                  child: Text("Fully stocked!", style: TextStyle(fontSize: 18)),
                );
              }

              // Group by category (no "service" category)
              final foodItems = needsShopping.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data["category"] ?? "food") == "food";
              }).toList();

              final suppliesItems = needsShopping.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final cat = data["category"] ?? "food";
                return cat == "supplies" || cat == "service";
              }).toList();

              final equipmentItems = needsShopping.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data["category"] ?? "food") == "equipment";
              }).toList();

              // Sort items alphabetically within each category
              foodItems.sort((a, b) {
                final aName = (a.data() as Map<String, dynamic>)["name"] ?? "";
                final bName = (b.data() as Map<String, dynamic>)["name"] ?? "";
                return aName.toLowerCase().compareTo(bName.toLowerCase());
              });

              suppliesItems.sort((a, b) {
                final aName = (a.data() as Map<String, dynamic>)["name"] ?? "";
                final bName = (b.data() as Map<String, dynamic>)["name"] ?? "";
                return aName.toLowerCase().compareTo(bName.toLowerCase());
              });

              equipmentItems.sort((a, b) {
                final aName = (a.data() as Map<String, dynamic>)["name"] ?? "";
                final bName = (b.data() as Map<String, dynamic>)["name"] ?? "";
                return aName.toLowerCase().compareTo(bName.toLowerCase());
              });

              return ListView(
                children: [
                  _categorySection("Food", foodItems),
                  _categorySection("Supplies", suppliesItems),
                  _categorySection("Equipment", equipmentItems),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categorySection(String title, List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text(
          "$title (${docs.length})",
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: false,
        children: docs.map((doc) => ShoppingCard(doc: doc)).toList(),
      ),
    );
  }
}
