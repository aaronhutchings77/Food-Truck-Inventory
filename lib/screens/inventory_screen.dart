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

  // Tracks which categories have been manually expanded (collapsed by default)
  final Map<String, Set<String>> _expandedCategories = {};

  // Multi-select state (checkboxes always visible)
  final Set<String> _selectedIds = {};

  // Cached docs for unchecked count
  List<QueryDocumentSnapshot> _allDocsCache = [];

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
      _expandedCategories[tabKey] ??= {};
      if (_expandedCategories[tabKey]!.contains(category)) {
        _expandedCategories[tabKey]!.remove(category);
      } else {
        _expandedCategories[tabKey]!.add(category);
      }
    });
  }

  bool _isCategoryExpanded(String tabKey, String category) {
    return _expandedCategories[tabKey]?.contains(category) ?? false;
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
      } else {
        _selectedIds.add(docId);
      }
    });
  }

  void _showBulkEditSheet() {
    if (_selectedIds.isEmpty) return;

    String? newCategory;
    final usedPerCtl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edit ${_selectedIds.length} Selected Items",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: newCategory,
                decoration: const InputDecoration(
                  labelText: "Change Category",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "food", child: Text("Food")),
                  DropdownMenuItem(value: "supplies", child: Text("Supplies")),
                  DropdownMenuItem(
                    value: "equipment",
                    child: Text("Equipment"),
                  ),
                ],
                onChanged: (v) => newCategory = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usedPerCtl,
                decoration: const InputDecoration(
                  labelText: "Change Used Per Service",
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final fields = <String, dynamic>{};
                    if (newCategory != null) {
                      fields["category"] = newCategory;
                    }
                    final usedPer = double.tryParse(usedPerCtl.text);
                    if (usedPer != null && usedPer >= 0) {
                      fields["usedPerService"] = usedPer;
                    }
                    if (fields.isEmpty) {
                      Navigator.pop(ctx);
                      return;
                    }
                    final count = _selectedIds.length;
                    await _service.bulkUpdate(_selectedIds.toList(), fields);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _clearSelection();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Updated $count items"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Save", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editTargetInline(
    String label,
    int currentValue,
    Future<void> Function(int) onSave,
  ) {
    final ctl = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $label"),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final val = int.tryParse(ctl.text);
              if (val != null && val > 0) {
                await onSave(val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selection mode AppBar overlay
        if (_selectedIds.isNotEmpty)
          Container(
            color: Colors.blue.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  "${_selectedIds.length} Selected",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _showBulkEditSheet,
                  child: const Text("Change Category"),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _showBulkEditSheet,
                  child: const Text("Change Used Per Service"),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: "Cancel",
                  onPressed: _clearSelection,
                ),
              ],
            ),
          ),
        // Global settings header + truck target + unchecked counter
        StreamBuilder<Map<String, int>>(
          stream: GlobalSettings.settingsStream,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? {};
            final target =
                settings["targetServices"] ?? GlobalSettings.targetServices;
            final truckTarget =
                settings["truckTargetServices"] ??
                GlobalSettings.truckTargetServices;
            final low =
                settings["lowServiceMultiplier"] ??
                GlobalSettings.lowServiceMultiplier;
            final crit =
                settings["criticalServiceMultiplier"] ??
                GlobalSettings.criticalServiceMultiplier;

            // Update cache
            if (snapshot.hasData) GlobalSettings.initialize(snapshot.data!);

            // Count unchecked truck items from cache
            final uncheckedCount = _allDocsCache.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data["truckVerifiedAt"] == null;
            }).length;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Inventory Levels (QTY of Services)",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _editTargetInline(
                      "Overall Target Services",
                      target,
                      (val) => GlobalSettings.updateAll(
                        targetServices: val,
                        truckTargetServices: truckTarget,
                        lowServiceMultiplier: low,
                        criticalServiceMultiplier: crit,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Overall Target Services: $target",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () => _editTargetInline(
                      "Truck Target Services",
                      truckTarget,
                      (val) => GlobalSettings.updateAll(
                        targetServices: target,
                        truckTargetServices: val,
                        lowServiceMultiplier: low,
                        criticalServiceMultiplier: crit,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Truck Target Services: $truckTarget",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                  if (uncheckedCount >= 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: uncheckedCount > 0
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: uncheckedCount > 0
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        "Unchecked Truck Items: $uncheckedCount",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: uncheckedCount > 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
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

          _allDocsCache = snapshot.data!.docs;

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

        _allDocsCache = snapshot.data!.docs;

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

        _allDocsCache = snapshot.data!.docs;

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

    final isExpanded = _isCategoryExpanded(tabKey, categoryKey);

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
                  isExpanded ? Icons.expand_less : Icons.expand_more,
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
        if (isExpanded)
          ...docs.map(
            (doc) => InventoryCard(
              key: ValueKey(doc.id),
              doc: doc,
              isSelected: _selectedIds.contains(doc.id),
              onSelectionToggle: () => _toggleSelection(doc.id),
            ),
          ),
      ],
    );
  }
}
