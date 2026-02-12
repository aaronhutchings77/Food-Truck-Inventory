import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/inventory_card.dart';
import '../settings/global_settings.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allDocs = [];
  List<QueryDocumentSnapshot> _filteredDocs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Food"),
            Tab(text: "Supplies"),
            Tab(text: "Equipment"),
          ],
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

              return TabBarView(
                controller: _tabController,
                children: [
                  _categoryView(docsToUse, "food"),
                  _categoryView(docsToUse, "supplies"),
                  _categoryView(docsToUse, "equipment"),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryView(List<QueryDocumentSnapshot> docs, String category) {
    List<QueryDocumentSnapshot> critical = [];
    List<QueryDocumentSnapshot> low = [];
    List<QueryDocumentSnapshot> good = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String itemCategory = data["category"] ?? "food";

      if (itemCategory != category) continue;

      double total = (data["truckAmount"] ?? 0.0) + (data["homeAmount"] ?? 0.0);
      double qtyPerService = data["qtyPerService"] ?? 1.0;
      double servicesRemaining = qtyPerService > 0 ? total / qtyPerService : 0;

      if (total <= (data["needToPurchase"] ?? 0) ||
          servicesRemaining < GlobalSettings.servicesTarget) {
        critical.add(doc);
      } else if (total <= (data["gettingLow"] ?? 0)) {
        low.add(doc);
      } else {
        good.add(doc);
      }
    }

    return ListView(
      children: [
        _section("🚨 Critical", critical),
        _section("⚠️ Low", low),
        _section("✅ Good", good),
      ],
    );
  }

  Widget _section(String title, List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...docs.map((doc) => InventoryCard(doc: doc)),
      ],
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
