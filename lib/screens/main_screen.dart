import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inventory_screen.dart';
import 'shopping_screen.dart';
import 'add_item_screen.dart';
import '../services/settings_service.dart';
import '../settings/global_settings.dart';

class MainScreen extends StatefulWidget {
  final User user;
  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;
  bool _settingsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    if (_settingsInitialized) return;

    try {
      final settingsService = SettingsService();
      await settingsService.initializeDefaultSettings();
      final target = await settingsService.getServicesTarget();
      GlobalSettings.initializeServicesTarget(target);
      setState(() {
        _settingsInitialized = true;
      });
    } catch (e) {
      print('Settings initialization error: $e');
      // Use default values if initialization fails
      GlobalSettings.initializeServicesTarget(5);
      setState(() {
        _settingsInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? "Inventory" : "Shopping"),
        actions: [
          if (index == 0)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddItemScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: index == 0 ? const InventoryScreen() : const ShoppingScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (v) => setState(() => index = v),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: "Inventory",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Shopping",
          ),
        ],
      ),
    );
  }
}
