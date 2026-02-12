import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/shopping_card.dart';
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
  final Map<String, bool> _expandedCategories = {
    "food": true,
    "supplies": true,
    "equipment": true,
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
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
        StreamBuilder<int>(
          stream: GlobalSettings.servicesTargetStream,
          builder: (context, snapshot) {
            final target = snapshot.data ?? 5;
            return Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Target Services: $target",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editTargetDialog(context, target),
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
            decoration: const InputDecoration(
              labelText: "Search items...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
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

              // Filter items that need restocking
              final needsRestock = docsToUse.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                double total =
                    (data["truckAmount"] ?? 0.0) + (data["homeAmount"] ?? 0.0);
                return total <= (data["gettingLow"] ?? 0);
              }).toList();

              if (needsRestock.isEmpty) {
                return const Center(child: Text("Nothing needs restocking."));
              }

              // Group by category
              final foodItems = needsRestock.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data["category"] ?? "food") == "food";
              }).toList();

              final suppliesItems = needsRestock.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data["category"] ?? "food") == "supplies";
              }).toList();

              final equipmentItems = needsRestock.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data["category"] ?? "food") == "equipment";
              }).toList();

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
        title: Text(title),
        initiallyExpanded: _expandedCategories[title.toLowerCase()] ?? true,
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedCategories[title.toLowerCase()] = expanded;
          });
        },
        children: docs.map((doc) => ShoppingCard(doc: doc)).toList(),
      ),
    );
  }

  void _editTargetDialog(BuildContext context, int currentTarget) {
    final controller = TextEditingController(text: currentTarget.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Target Services"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Target Services"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newTarget = int.tryParse(controller.text);
              if (newTarget != null && newTarget > 0) {
                await GlobalSettings.updateServicesTarget(newTarget);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
