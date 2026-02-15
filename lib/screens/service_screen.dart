import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/service_workflow_service.dart';
import '../services/general_todo_service.dart';
import '../settings/global_settings.dart';

class ServiceScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToInventory;

  const ServiceScreen({super.key, this.onNavigateToInventory});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final ServiceWorkflowService _service = ServiceWorkflowService();
  final GeneralTodoService _todoService = GeneralTodoService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.initializeTemplate();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _service.getSessionStream(),
      builder: (context, sessionSnapshot) {
        final sessionData =
            sessionSnapshot.data?.data() as Map<String, dynamic>?;
        final isActive = sessionData?['active'] == true;

        return StreamBuilder<DocumentSnapshot>(
          stream: _service.getTemplateStream(),
          builder: (context, templateSnapshot) {
            return Column(
              children: [
                // Inventory reminder banners
                _buildReminderBanners(),
                // Start / Complete buttons
                _buildActionButtons(isActive),
                const Divider(height: 1),
                // Checklist content
                Expanded(
                  child: ListView(
                    children: [
                      _buildGeneralTodoSection(),
                      const Divider(height: 1),
                      if (isActive)
                        ..._buildSessionChecklistItems(sessionData!)
                      else
                        ..._buildTemplateViewItems(templateSnapshot),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReminderBanners() {
    return StreamBuilder<Map<String, Timestamp?>>(
      stream: GlobalSettings.inventorySessionsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        GlobalSettings.initializeInventorySessions(snapshot.data!);

        final now = DateTime.now();
        final banners = <Widget>[];

        // Check each cadence for truck and home
        final cadences = {'weekly': 7, 'monthly': 30};

        for (final entry in cadences.entries) {
          final cadence = entry.key;
          final days = entry.value;
          final label = cadence[0].toUpperCase() + cadence.substring(1);

          final truckTs = GlobalSettings.getTruckInventorySession(cadence);
          final homeTs = GlobalSettings.getHomeInventorySession(cadence);

          final truckDue = _isDue(truckTs, now, days);
          final homeDue = _isDue(homeTs, now, days);

          if (truckDue) {
            banners.add(
              _reminderBanner(
                '$label Truck Inventory Due',
                Colors.orange.shade100,
                Colors.orange.shade800,
              ),
            );
          }
          if (homeDue) {
            banners.add(
              _reminderBanner(
                '$label Home Inventory Due',
                Colors.orange.shade100,
                Colors.orange.shade800,
              ),
            );
          }
        }

        if (banners.isEmpty) return const SizedBox.shrink();
        return Column(children: banners);
      },
    );
  }

  bool _isDue(Timestamp? lastStarted, DateTime now, int days) {
    if (lastStarted == null) return true;
    final lastDate = lastStarted.toDate();
    return now.difference(lastDate).inDays >= days;
  }

  Widget _reminderBanner(String text, Color bgColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isActive) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (!isActive)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startService,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          if (isActive) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _completeService,
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start Service'),
        content: const Text(
          'Start a new service session? This will reset checklist completion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.startService();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service session started'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _completeService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Complete Service'),
        content: const Text(
          'Complete this service? One-time tasks will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.completeService();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service completed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // --- General To-Do Section ---

  Widget _buildGeneralTodoSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _todoService.getTodosStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: const Text(
              'General To-Do List',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${docs.where((d) => (d.data() as Map<String, dynamic>)['completed'] != true).length} pending',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            initiallyExpanded: true,
            children: [
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final completed = data['completed'] == true;
                final title = data['title'] ?? '';
                final note = data['note'] ?? '';

                return ListTile(
                  leading: Checkbox(
                    value: completed,
                    onChanged: (val) {
                      _todoService.toggleTodo(doc.id, val ?? false);
                    },
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      decoration: completed ? TextDecoration.lineThrough : null,
                      color: completed ? Colors.grey : null,
                    ),
                  ),
                  subtitle: note.isNotEmpty
                      ? Text(
                          note,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () =>
                            _showEditTodoDialog(doc.id, title, note),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                        onPressed: () => _confirmDeleteTodo(doc.id, title),
                      ),
                    ],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: OutlinedButton.icon(
                  onPressed: _showAddTodoDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add To-Do'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddTodoDialog() async {
    final titleCtl = TextEditingController();
    final noteCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add To-Do'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              decoration: const InputDecoration(
                labelText: 'Task name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (titleCtl.text.trim().isEmpty) return;
              await _todoService.addTodo(
                titleCtl.text.trim(),
                noteCtl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    titleCtl.dispose();
    noteCtl.dispose();
  }

  Future<void> _showEditTodoDialog(
    String id,
    String currentTitle,
    String currentNote,
  ) async {
    final titleCtl = TextEditingController(text: currentTitle);
    final noteCtl = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit To-Do'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtl,
              decoration: const InputDecoration(
                labelText: 'Task name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (titleCtl.text.trim().isEmpty) return;
              await _todoService.updateTodo(
                id,
                titleCtl.text.trim(),
                noteCtl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    titleCtl.dispose();
    noteCtl.dispose();
  }

  Future<void> _confirmDeleteTodo(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete To-Do?'),
        content: Text('Delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _todoService.deleteTodo(id);
    }
  }

  // --- Active Session Checklist ---

  List<Widget> _buildSessionChecklistItems(Map<String, dynamic> sessionData) {
    final phases = Map<String, dynamic>.from(sessionData['phases'] ?? {});

    return ServiceWorkflowService.phaseNames.map((phase) {
      final key = phase.replaceAll(' ', '_').toLowerCase();
      final items = List<Map<String, dynamic>>.from(
        (phases[key] as List<dynamic>?) ?? [],
      );

      return _buildPhaseSection(phase, items, isSession: true);
    }).toList();
  }

  // --- Template View (no active session) ---

  List<Widget> _buildTemplateViewItems(
    AsyncSnapshot<DocumentSnapshot> templateSnapshot,
  ) {
    final templateData = templateSnapshot.data?.data() as Map<String, dynamic>?;
    final phases = Map<String, dynamic>.from(templateData?['phases'] ?? {});

    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          'Service Template',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Manage recurring and one-time checklist items.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ),
      const SizedBox(height: 8),
      ...ServiceWorkflowService.phaseNames.map((phase) {
        final key = phase.replaceAll(' ', '_').toLowerCase();
        final items = List<Map<String, dynamic>>.from(
          (phases[key] as List<dynamic>?) ?? [],
        );
        return _buildPhaseSection(phase, items, isSession: false);
      }),
    ];
  }

  Widget _buildPhaseSection(
    String phase,
    List<Map<String, dynamic>> items, {
    required bool isSession,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text(
          phase,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: isSession
            ? Text(
                '${items.where((i) => i['completed'] == true).length}/${items.length} completed',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      items.every((i) => i['completed'] == true) &&
                          items.isNotEmpty
                      ? Colors.green
                      : Colors.grey,
                ),
              )
            : Text(
                '${items.length} items',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
        initiallyExpanded: isSession,
        children: [
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildChecklistItem(phase, index, item, isSession);
          }),
          if (!isSession)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showAddItemDialog(phase),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(
    String phase,
    int index,
    Map<String, dynamic> item,
    bool isSession,
  ) {
    final title = item['title'] ?? '';
    final isRecurring = item['isRecurring'] == true;
    final isSystem = item['isSystem'] == true;
    final completed = item['completed'] == true;

    if (isSession) {
      return ListTile(
        leading: Checkbox(
          value: completed,
          onChanged: (val) {
            _service.toggleSessionItem(phase, index, val ?? false);
          },
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            decoration: completed ? TextDecoration.lineThrough : null,
            color: completed ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (isSystem)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'System',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ),
            if (!isRecurring && !isSystem) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'One-time',
                  style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
                ),
              ),
            ],
          ],
        ),
        trailing: isSystem && title == 'Perform Per Service Truck Inventory'
            ? TextButton(
                onPressed: () {
                  // Navigate to inventory Per Service tab (index 0)
                  widget.onNavigateToInventory?.call(0);
                },
                child: const Text('Go to Inventory'),
              )
            : null,
      );
    }

    // Template view
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        isRecurring ? 'Recurring' : 'One-time (next service only)',
        style: TextStyle(
          fontSize: 12,
          color: isRecurring ? Colors.green.shade700 : Colors.purple.shade700,
        ),
      ),
      trailing: !isSystem
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () =>
                      _showEditItemDialog(phase, index, title, isRecurring),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _confirmDeleteItem(phase, index, title),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _showAddItemDialog(String phase) async {
    final titleCtl = TextEditingController();
    bool isRecurring = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add to "$phase"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(
                  labelText: 'Task description',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: true, label: Text('Recurring')),
                  ButtonSegment<bool>(value: false, label: Text('One-time')),
                ],
                selected: {isRecurring},
                onSelectionChanged: (Set<bool> newSelection) {
                  setDialogState(() => isRecurring = newSelection.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty) return;
                await _service.addChecklistItem(
                  phase,
                  titleCtl.text.trim(),
                  isRecurring,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    titleCtl.dispose();
  }

  Future<void> _showEditItemDialog(
    String phase,
    int index,
    String currentTitle,
    bool currentIsRecurring,
  ) async {
    final titleCtl = TextEditingController(text: currentTitle);
    bool isRecurring = currentIsRecurring;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit "$phase" item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(
                  labelText: 'Task description',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: true, label: Text('Recurring')),
                  ButtonSegment<bool>(value: false, label: Text('One-time')),
                ],
                selected: {isRecurring},
                onSelectionChanged: (Set<bool> newSelection) {
                  setDialogState(() => isRecurring = newSelection.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty) return;
                await _service.updateChecklistItem(
                  phase,
                  index,
                  titleCtl.text.trim(),
                  isRecurring,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    titleCtl.dispose();
  }

  Future<void> _confirmDeleteItem(String phase, int index, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Item?'),
        content: Text('Remove "$title" from template?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.removeChecklistItem(phase, index);
    }
  }
}
