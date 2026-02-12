import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/inventory_card.dart';
import '../settings/global_settings.dart';
import '../services/inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final InventoryService _service = InventoryService();
  final List<String> _tabs = [
    "Per Service",
    "Daily",
    "Weekly",
    "Monthly",
    "Quarterly",
    "Warnings",
    "All",
  ];

  final Map<String, Set<String>> _collapsedCategories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCategory(String tabKey, String category) {
    setState(() {
      _collapsedCategories[tabKey] ??= {};
      if (_collapsedCategories[tabKey]!.contains(category)) {
        _collapsedCategories[tabKey]!.remove(category);
      } else {
        _collapsedCategories[tabKey]!.add(category);
      }
    });
  }

  bool _isCategoryCollapsed(String tabKey, String category) {
    return _collapsedCategories[tabKey]?.contains(category) ?? false;
  }

  static bool isOverdue(String frequency, Timestamp? lastCheckedAt) {
    if (lastCheckedAt == null) return true;

    final lastChecked = lastCheckedAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastChecked);

    switch (frequency) {
      case "perService":
        return difference.inDays >= 1;
      case "daily":
        return difference.inDays >= 1;
      case "weekly":
        return difference.inDays >= 7;
      case "monthly":
        return difference.inDays >= 30;
      case "quarterly":
        return difference.inDays >= 90;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Global settings header
        StreamBuilder<Map<String, int>>(
          stream: GlobalSettings.settingsStream,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? {};
            final target =
                settings["targetServices"] ?? GlobalSettings.targetServices;
            final low =
                settings["lowServiceMultiplier"] ??
                GlobalSettings.lowServiceMultiplier;
            final crit =
                settings["criticalServiceMultiplier"] ??
                GlobalSettings.criticalServiceMultiplier;

            // Update cache
            if (snapshot.hasData) GlobalSettings.initialize(snapshot.data!);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Inventory Levels (QTY of Services)",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Overall Target: $target",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Getting Low: $low",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Need to Purchase: $crit",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
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
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _frequencyTab("perService"),
              _frequencyTab("daily"),
              _frequencyTab("weekly"),
              _frequencyTab("monthly"),
              _frequencyTab("quarterly"),
              _warningsTab(),
              _allItemsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _frequencyTab(String frequency) {
    // For perService, also include legacy items without inventoryFrequency
    if (frequency == "perService") {
      return StreamBuilder<QuerySnapshot>(
        stream: _service.getAllItems(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = _filterBySearch(snapshot.data!.docs).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final freq = data["inventoryFrequency"] ?? data["checkFrequency"];
            return freq == "perService" || freq == "service" || freq == null;
          }).toList();

          return _buildCategoryGroupedList(docs, frequency);
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _service.getItemsByFrequency(frequency),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = _filterBySearch(snapshot.data!.docs);
        return _buildCategoryGroupedList(docs, frequency);
      },
    );
  }

  Widget _warningsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getAllItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = _filterBySearch(snapshot.data!.docs).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return InventoryCard.isWarning(data);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No items in warning state",
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return _buildCategoryGroupedList(docs, "warnings");
      },
    );
  }

  Widget _allItemsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getAllItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = _filterBySearch(snapshot.data!.docs);
        return _buildCategoryGroupedList(docs, "all");
      },
    );
  }

  List<QueryDocumentSnapshot> _filterBySearch(
    List<QueryDocumentSnapshot> docs,
  ) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data["name"] ?? "").toLowerCase();
      final model = (data["model"] ?? "").toLowerCase();
      final unitType = (data["unitType"] ?? "").toLowerCase();
      return name.contains(query) ||
          model.contains(query) ||
          unitType.contains(query);
    }).toList();
  }

  Widget _buildCategoryGroupedList(
    List<QueryDocumentSnapshot> docs,
    String tabKey,
  ) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {
      "food": [],
      "supplies": [],
      "equipment": [],
    };

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String category = data["category"] ?? "food";
      if (category == "service") category = "supplies";
      if (grouped.containsKey(category)) {
        grouped[category]!.add(doc);
      } else {
        grouped["food"]!.add(doc);
      }
    }

    return ListView(
      children: [
        _collapsibleCategorySection("Food", "food", grouped["food"]!, tabKey),
        _collapsibleCategorySection(
          "Supplies",
          "supplies",
          grouped["supplies"]!,
          tabKey,
        ),
        _collapsibleCategorySection(
          "Equipment",
          "equipment",
          grouped["equipment"]!,
          tabKey,
        ),
      ],
    );
  }

  Widget _collapsibleCategorySection(
    String title,
    String categoryKey,
    List<QueryDocumentSnapshot> docs,
    String tabKey,
  ) {
    if (docs.isEmpty) return const SizedBox();

    final isCollapsed = _isCategoryCollapsed(tabKey, categoryKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleCategory(tabKey, categoryKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                Icon(
                  isCollapsed ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "$title (${docs.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isCollapsed)
          ...docs.map(
            (doc) => InventoryCard(
              doc: doc,
              showCheckButton: true,
              isOverdue: _checkIfOverdue(doc),
            ),
          ),
      ],
    );
  }

  bool _checkIfOverdue(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final frequency =
        (data["inventoryFrequency"] ?? data["checkFrequency"]) as String?;
    final lastCheckedAt = data["lastCheckedAt"] as Timestamp?;

    if (frequency == null) return false;
    return isOverdue(frequency, lastCheckedAt);
  }
}
