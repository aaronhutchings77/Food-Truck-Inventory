import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/inventory_card.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Food"),
            Tab(text: "Service"),
            Tab(text: "Equipment"),
          ],
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("items").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _categoryView(snapshot.data!.docs, "food"),
                  _categoryView(snapshot.data!.docs, "service"),
                  _categoryView(snapshot.data!.docs, "equipment"),
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

      if (total <= (data["needToPurchase"] ?? 0)) {
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
}
