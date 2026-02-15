import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServiceWorkflowService {
  final _db = FirebaseFirestore.instance;

  static const List<String> phaseNames = [
    'Before Leaving House',
    'Pick Up Truck',
    'At Service Location',
    'Before Leaving Service Location',
    'Drop Off Truck',
    'Before Next Service',
  ];

  DocumentReference get _templateDoc =>
      _db.collection('serviceTemplate').doc('default');

  DocumentReference get _sessionDoc =>
      _db.collection('serviceSessions').doc('active');

  /// Get the service template stream
  Stream<DocumentSnapshot> getTemplateStream() {
    return _templateDoc.snapshots();
  }

  /// Get the active session stream
  Stream<DocumentSnapshot> getSessionStream() {
    return _sessionDoc.snapshots();
  }

  /// Initialize template if it doesn't exist
  Future<void> initializeTemplate() async {
    final doc = await _templateDoc.get();
    if (!doc.exists) {
      final phases = <String, dynamic>{};
      for (final phase in phaseNames) {
        phases[_phaseKey(phase)] = <Map<String, dynamic>>[];
      }
      await _templateDoc.set({
        'phases': phases,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Add a checklist item to a phase in the template
  Future<void> addChecklistItem(
    String phase,
    String title,
    bool isRecurring,
  ) async {
    final doc = await _templateDoc.get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final phases = Map<String, dynamic>.from(data['phases'] ?? {});
    final key = _phaseKey(phase);
    final items = List<Map<String, dynamic>>.from(
      (phases[key] as List<dynamic>?) ?? [],
    );

    items.add({
      'title': title,
      'isRecurring': isRecurring,
      'createdAt': DateTime.now().toIso8601String(),
    });

    phases[key] = items;
    await _templateDoc.set({'phases': phases}, SetOptions(merge: true));
  }

  /// Update a checklist item in the template
  Future<void> updateChecklistItem(
    String phase,
    int index,
    String title,
    bool isRecurring,
  ) async {
    final doc = await _templateDoc.get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final phases = Map<String, dynamic>.from(data['phases'] ?? {});
    final key = _phaseKey(phase);
    final items = List<Map<String, dynamic>>.from(
      (phases[key] as List<dynamic>?) ?? [],
    );

    if (index >= 0 && index < items.length) {
      items[index] = Map<String, dynamic>.from(items[index]);
      items[index]['title'] = title;
      items[index]['isRecurring'] = isRecurring;
      phases[key] = items;
      await _templateDoc.set({'phases': phases}, SetOptions(merge: true));
    }
  }

  /// Remove a checklist item from a phase in the template
  Future<void> removeChecklistItem(String phase, int index) async {
    final doc = await _templateDoc.get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final phases = Map<String, dynamic>.from(data['phases'] ?? {});
    final key = _phaseKey(phase);
    final items = List<Map<String, dynamic>>.from(
      (phases[key] as List<dynamic>?) ?? [],
    );

    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      phases[key] = items;
      await _templateDoc.set({'phases': phases}, SetOptions(merge: true));
    }
  }

  /// Start a new service session
  Future<void> startService() async {
    final templateDoc = await _templateDoc.get();
    final templateData = templateDoc.data() as Map<String, dynamic>? ?? {};
    final templatePhases = Map<String, dynamic>.from(
      templateData['phases'] ?? {},
    );

    // Build session checklist from template
    final sessionPhases = <String, dynamic>{};
    for (final phase in phaseNames) {
      final key = _phaseKey(phase);
      final templateItems = List<Map<String, dynamic>>.from(
        (templatePhases[key] as List<dynamic>?) ?? [],
      );

      final sessionItems = templateItems.map((item) {
        return {
          'title': item['title'],
          'isRecurring': item['isRecurring'] ?? true,
          'completed': false,
          'isSystem': false,
        };
      }).toList();

      // Auto-add system task under "Drop Off Truck"
      if (phase == 'Drop Off Truck') {
        sessionItems.add({
          'title': 'Perform Per Service Truck Inventory',
          'isRecurring': true,
          'completed': false,
          'isSystem': true,
        });
      }

      sessionPhases[key] = sessionItems;
    }

    await _sessionDoc.set({
      'active': true,
      'phases': sessionPhases,
      'startedAt': FieldValue.serverTimestamp(),
      'startedBy': FirebaseAuth.instance.currentUser?.email,
    });
  }

  /// Toggle completion of a checklist item in the active session
  Future<void> toggleSessionItem(
    String phase,
    int index,
    bool completed,
  ) async {
    final doc = await _sessionDoc.get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final phases = Map<String, dynamic>.from(data['phases'] ?? {});
    final key = _phaseKey(phase);
    final items = List<Map<String, dynamic>>.from(
      (phases[key] as List<dynamic>?) ?? [],
    );

    if (index >= 0 && index < items.length) {
      items[index] = Map<String, dynamic>.from(items[index]);
      items[index]['completed'] = completed;
      phases[key] = items;
      await _sessionDoc.update({'phases': phases});
    }
  }

  /// Complete the active service session
  Future<void> completeService() async {
    // Remove one-time items from template
    final templateDoc = await _templateDoc.get();
    final templateData = templateDoc.data() as Map<String, dynamic>? ?? {};
    final templatePhases = Map<String, dynamic>.from(
      templateData['phases'] ?? {},
    );

    for (final phase in phaseNames) {
      final key = _phaseKey(phase);
      final items = List<Map<String, dynamic>>.from(
        (templatePhases[key] as List<dynamic>?) ?? [],
      );
      // Keep only recurring items
      final recurring = items
          .where((item) => item['isRecurring'] == true)
          .toList();
      templatePhases[key] = recurring;
    }

    await _templateDoc.set({'phases': templatePhases}, SetOptions(merge: true));

    // Close session
    await _sessionDoc.set({
      'active': false,
      'completedAt': FieldValue.serverTimestamp(),
      'completedBy': FirebaseAuth.instance.currentUser?.email,
    }, SetOptions(merge: true));
  }

  /// Check if there is an active session
  Future<bool> hasActiveSession() async {
    final doc = await _sessionDoc.get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return data['active'] == true;
  }

  String _phaseKey(String phase) {
    return phase.replaceAll(' ', '_').toLowerCase();
  }
}
