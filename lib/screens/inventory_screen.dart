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
    "Service",
    "Weekly",
    "Monthly",
    "Quarterly",
    "Getting Low",
    "All",
  ];

  // Track collapsed state by category for each tab
  final Map<String, Set<String>> _collapsedCategories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Initialize collapsed categories for Service tab (default collapsed)
    _collapsedCategories["service"] = {"food", "supplies", "equipment"};
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

  static bool isOverdue(String checkFrequency, Timestamp? lastCheckedAt) {
    if (lastCheckedAt == null) return true;

    final lastChecked = lastCheckedAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastChecked);

    switch (checkFrequency) {
      case "service":
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
          isScrollable: true,
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
              _frequencyTab("service"),
              _frequencyTab("weekly"),
              _frequencyTab("monthly"),
              _frequencyTab("quarterly"),
              _gettingLowTab(),
              _allItemsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _frequencyTab(String frequency) {
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

  Widget _gettingLowTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getAllItems(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = _filterBySearch(snapshot.data!.docs).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          double total =
              (data["truckAmount"] ?? 0.0) + (data["homeAmount"] ?? 0.0);
          double qtyPerService = data["qtyPerService"] ?? 1.0;
          double servicesRemaining = qtyPerService > 0
              ? total / qtyPerService
              : 0;

          return total <= (data["gettingLow"] ?? 0) ||
              total <= (data["needToPurchase"] ?? 0) ||
              servicesRemaining < GlobalSettings.servicesTarget;
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No items are getting low",
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return _buildCategoryGroupedList(docs, "gettingLow");
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
    final checkFrequency = data["checkFrequency"] as String?;
    final lastCheckedAt = data["lastCheckedAt"] as Timestamp?;

    if (checkFrequency == null) return false;
    return isOverdue(checkFrequency, lastCheckedAt);
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
