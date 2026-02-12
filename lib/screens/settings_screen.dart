import 'package:flutter/material.dart';
import '../settings/global_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _targetController;
  late TextEditingController _truckTargetController;
  late TextEditingController _lowController;
  late TextEditingController _criticalController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _targetController = TextEditingController(
      text: GlobalSettings.targetServices.toString(),
    );
    _truckTargetController = TextEditingController(
      text: GlobalSettings.truckTargetServices.toString(),
    );
    _lowController = TextEditingController(
      text: GlobalSettings.lowServiceMultiplier.toString(),
    );
    _criticalController = TextEditingController(
      text: GlobalSettings.criticalServiceMultiplier.toString(),
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    _truckTargetController.dispose();
    _lowController.dispose();
    _criticalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = int.tryParse(_targetController.text);
    final truckTarget = int.tryParse(_truckTargetController.text);
    final low = int.tryParse(_lowController.text);
    final critical = int.tryParse(_criticalController.text);

    if (target == null || target < 1) {
      _showError("Overall Target Services must be a positive number");
      return;
    }
    if (truckTarget == null || truckTarget < 1) {
      _showError("Truck Target Services must be a positive number");
      return;
    }
    if (low == null || low < 0) {
      _showError("Getting Low multiplier must be >= 0");
      return;
    }
    if (critical == null || critical < 0) {
      _showError("Critical multiplier must be >= 0");
      return;
    }

    setState(() => _saving = true);
    try {
      await GlobalSettings.updateAll(
        targetServices: target,
        truckTargetServices: truckTarget,
        lowServiceMultiplier: low,
        criticalServiceMultiplier: critical,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Settings saved"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError("Failed to save: $e");
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text(
            "Global Settings",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _settingsField(
            "Overall Target Services",
            _targetController,
            "Number of services to plan overall inventory for",
          ),
          const SizedBox(height: 16),
          _settingsField(
            "Truck Target Services",
            _truckTargetController,
            "Number of services the truck should be stocked for",
          ),
          const SizedBox(height: 16),
          _settingsField(
            "Getting Low (services)",
            _lowController,
            "Warn when services remaining <= this value",
          ),
          const SizedBox(height: 16),
          _settingsField(
            "Need to Purchase (services)",
            _criticalController,
            "Critical warning when services remaining <= this value",
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Save Settings", style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _settingsField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        helperText: hint,
        helperStyle: const TextStyle(fontSize: 14),
        border: const OutlineInputBorder(),
      ),
      style: const TextStyle(fontSize: 18),
      keyboardType: TextInputType.number,
    );
  }
}
