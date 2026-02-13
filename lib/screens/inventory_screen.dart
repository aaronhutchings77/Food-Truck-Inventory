import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/inventory_card.dart';
import '../settings/global_settings.dart';
import '../services/inventory_service.dart';
import '../models/inventory_mode.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum InventoryFilter { all, verified, notVerified }

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

  // Inventory status filter
  InventoryFilter _statusFilter = InventoryFilter.all;

  // Mode toggle (Truck/Home/Both)
  InventoryMode _mode = InventoryMode.truck;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Never started";
    final date = timestamp.toDate();
    return "${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  void _startTruckInventorySession(String tabKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Start Truck Inventory Session"),
        content: Text(
          "Start a new truck inventory session for this tab? This will reset truck verification status.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Start"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetTruckVerificationForTab(tabKey);
      await GlobalSettings.updateTruckInventorySession(tabKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Truck inventory session started"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _startHomeInventorySession(String tabKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Start Home Inventory Session"),
        content: Text(
          "Start a new home inventory session for this tab? This will reset home verification status.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Start"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetHomeVerificationForTab(tabKey);
      await GlobalSettings.updateHomeInventorySession(tabKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Home inventory session started"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
        // Keep settings stream alive for GlobalSettings cache
        StreamBuilder<Map<String, int>>(
          stream: GlobalSettings.settingsStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              GlobalSettings.initialize(snapshot.data!);
            }
            return const SizedBox.shrink();
          },
        ),
        // Keep inventory sessions stream alive for GlobalSettings cache
        StreamBuilder<Map<String, Timestamp?>>(
          stream: GlobalSettings.inventorySessionsStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              GlobalSettings.initializeInventorySessions(snapshot.data!);
            }
            return const SizedBox.shrink();
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
        // Mode toggle (Truck/Home/Both)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SegmentedButton<InventoryMode>(
            segments: const [
              ButtonSegment<InventoryMode>(
                value: InventoryMode.truck,
                label: Text('Truck'),
              ),
              ButtonSegment<InventoryMode>(
                value: InventoryMode.home,
                label: Text('Home'),
              ),
              ButtonSegment<InventoryMode>(
                value: InventoryMode.both,
                label: Text('Both'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (Set<InventoryMode> newSelection) {
              setState(() {
                _mode = newSelection.first;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        // Status filter control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              const Text(
                "Status: ",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<InventoryFilter>(
                  segments: const [
                    ButtonSegment<InventoryFilter>(
                      value: InventoryFilter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment<InventoryFilter>(
                      value: InventoryFilter.verified,
                      label: Text('Verified'),
                    ),
                    ButtonSegment<InventoryFilter>(
                      value: InventoryFilter.notVerified,
                      label: Text('Not Verified'),
                    ),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (Set<InventoryFilter> newSelection) {
                    setState(() {
                      _statusFilter = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
    final tabKey = frequency;

    return Column(
      children: [
        // Status display based on mode
        _buildStatusDisplay(tabKey),
        // Start Inventory buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _startTruckInventorySession(tabKey),
                icon: const Icon(Icons.local_shipping),
                label: const Text("Start Truck Inventory"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _startHomeInventorySession(tabKey),
                icon: const Icon(Icons.home),
                label: const Text("Start Home Inventory"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(child: _buildTabContent(frequency)),
      ],
    );
  }

  Widget _buildStatusDisplay(String tabKey) {
    final truckLastStarted = GlobalSettings.getTruckInventorySession(tabKey);
    final homeLastStarted = GlobalSettings.getHomeInventorySession(tabKey);

    if (_mode == InventoryMode.truck) {
      return FutureBuilder<int>(
        future: _getUncheckedCount(tabKey, 'truck'),
        builder: (context, snapshot) {
          final uncheckedCount = snapshot.data ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  "Truck Unchecked: $uncheckedCount",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Last Truck Start: ${_formatTimestamp(truckLastStarted)}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (_mode == InventoryMode.home) {
      return FutureBuilder<int>(
        future: _getUncheckedCount(tabKey, 'home'),
        builder: (context, snapshot) {
          final uncheckedCount = snapshot.data ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  "Home Unchecked: $uncheckedCount",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Last Home Start: ${_formatTimestamp(homeLastStarted)}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Both mode
      return FutureBuilder<Map<String, int>>(
        future: _getBothUncheckedCounts(tabKey),
        builder: (context, snapshot) {
          final truckUnchecked = snapshot.data?['truck'] ?? 0;
          final homeUnchecked = snapshot.data?['home'] ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Truck Unchecked: $truckUnchecked",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Home Unchecked: $homeUnchecked",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "Last Truck Start: ${_formatTimestamp(truckLastStarted)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Last Home Start: ${_formatTimestamp(homeLastStarted)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<int> _getUncheckedCount(String tabKey, String type) async {
    QuerySnapshot snapshot;

    if (tabKey == "perService") {
      snapshot = await _service.itemsCollection.get();
      final docs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final freq = data["inventoryFrequency"] ?? data["checkFrequency"];
        return freq == "perService" || freq == "service" || freq == null;
      }).toList();

      return docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final verifiedField = type == 'truck'
            ? "truckVerifiedAt"
            : "homeVerifiedAt";
        return data[verifiedField] == null;
      }).length;
    } else if (tabKey == "all") {
      snapshot = await _service.itemsCollection.get();
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final verifiedField = type == 'truck'
            ? "truckVerifiedAt"
            : "homeVerifiedAt";
        return data[verifiedField] == null;
      }).length;
    } else if (tabKey == "warnings") {
      snapshot = await _service.itemsCollection.get();
      final docs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return InventoryCard.isWarning(data);
      }).toList();

      return docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final verifiedField = type == 'truck'
            ? "truckVerifiedAt"
            : "homeVerifiedAt";
        return data[verifiedField] == null;
      }).length;
    } else {
      snapshot = await _service.itemsCollection
          .where("inventoryFrequency", isEqualTo: tabKey)
          .get();
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final verifiedField = type == 'truck'
            ? "truckVerifiedAt"
            : "homeVerifiedAt";
        return data[verifiedField] == null;
      }).length;
    }
  }

  Future<Map<String, int>> _getBothUncheckedCounts(String tabKey) async {
    final truckCount = await _getUncheckedCount(tabKey, 'truck');
    final homeCount = await _getUncheckedCount(tabKey, 'home');
    return {'truck': truckCount, 'home': homeCount};
  }

  Widget _buildTabContent(String frequency) {
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
    final tabKey = "warnings";

    return Column(
      children: [
        // Status display based on mode
        _buildStatusDisplay(tabKey),
        // Start Inventory buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _startTruckInventorySession(tabKey),
                icon: const Icon(Icons.local_shipping),
                label: const Text("Start Truck Inventory"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _startHomeInventorySession(tabKey),
                icon: const Icon(Icons.home),
                label: const Text("Start Home Inventory"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
          ),
        ),
      ],
    );
  }

  Widget _allItemsTab() {
    final tabKey = "all";

    return Column(
      children: [
        // Status display based on mode
        _buildStatusDisplay(tabKey),
        // Start Inventory buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _startTruckInventorySession(tabKey),
                icon: const Icon(Icons.local_shipping),
                label: const Text("Start Truck Inventory"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _startHomeInventorySession(tabKey),
                icon: const Icon(Icons.home),
                label: const Text("Start Home Inventory"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _service.getAllItems(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = _filterBySearch(snapshot.data!.docs);
              return _buildCategoryGroupedList(docs, "all");
            },
          ),
        ),
      ],
    );
  }

  List<QueryDocumentSnapshot> _filterBySearch(
    List<QueryDocumentSnapshot> docs,
  ) {
    final query = _searchController.text.toLowerCase();
    var filteredDocs = docs;

    // Apply search filter
    if (query.isNotEmpty) {
      filteredDocs = filteredDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data["name"] ?? "").toLowerCase();
        final model = (data["model"] ?? "").toLowerCase();
        final unitType = (data["unitType"] ?? "").toLowerCase();
        return name.contains(query) ||
            model.contains(query) ||
            unitType.contains(query);
      }).toList();
    }

    // Apply status filter based on mode
    if (_statusFilter != InventoryFilter.all) {
      filteredDocs = filteredDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        if (_mode == InventoryMode.truck) {
          final verified = data["truckVerifiedAt"] != null;
          return _statusFilter == InventoryFilter.verified
              ? verified
              : !verified;
        } else if (_mode == InventoryMode.home) {
          final verified = data["homeVerifiedAt"] != null;
          return _statusFilter == InventoryFilter.verified
              ? verified
              : !verified;
        } else {
          // Both: item passes if both are verified (for verified filter)
          // or if either is not verified (for not verified filter)
          final truckVerified = data["truckVerifiedAt"] != null;
          final homeVerified = data["homeVerifiedAt"] != null;
          if (_statusFilter == InventoryFilter.verified) {
            return truckVerified && homeVerified;
          } else {
            return !truckVerified || !homeVerified;
          }
        }
      }).toList();
    }

    return filteredDocs;
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

    // Sort items alphabetically within each category
    for (var category in grouped.keys) {
      grouped[category]!.sort((a, b) {
        final aName = (a.data() as Map<String, dynamic>)["name"] ?? "";
        final bName = (b.data() as Map<String, dynamic>)["name"] ?? "";
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });
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
              mode: _mode,
            ),
          ),
      ],
    );
  }
}
