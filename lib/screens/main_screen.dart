import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inventory_screen.dart';
import 'shopping_screen.dart';
import 'transfers_screen.dart';
import 'add_item_screen.dart';
import 'settings_screen.dart';
import '../services/settings_service.dart';
import '../services/inventory_service.dart';
import '../settings/global_settings.dart';

class MainScreen extends StatefulWidget {
  final User user;
  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      final settingsService = SettingsService();
      await settingsService.initializeDefaultSettings();
      final settings = await settingsService.getSettings();
      GlobalSettings.initialize(settings);

      // Run migration (non-blocking, safe to call multiple times)
      final inventoryService = InventoryService();
      await inventoryService.runMigration();
    } catch (e) {
      print('Initialization error: $e');
      GlobalSettings.initialize({});
    }

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ["Inventory", "Shopping", "Transfers"];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          if (index == 0)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddItemScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (v) => setState(() => index = v),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory),
              label: "Inventory",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: "Shopping",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz),
              label: "Transfers",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (index) {
      case 0:
        return const InventoryScreen();
      case 1:
        return const ShoppingScreen();
      case 2:
        return const TransfersScreen();
      default:
        return const InventoryScreen();
    }
  }
}
