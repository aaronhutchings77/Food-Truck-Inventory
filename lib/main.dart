import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SignInScreen();
        return InventoryScreen(user: snapshot.data!);
      },
    );
  }
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  Future<void> signIn() async {
    final provider = GoogleAuthProvider();
    await FirebaseAuth.instance.signInWithPopup(provider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: signIn,
          child: const Text("Sign in with Google"),
        ),
      ),
    );
  }
}

class InventoryScreen extends StatelessWidget {
  final User user;
  const InventoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              return ItemCard(
                doc: data,
                user: user,
              );
            },
          );
        },
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final User user;

  const ItemCard({super.key, required this.doc, required this.user});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;

    double truck = (data['truckAmount'] ?? 0).toDouble();
    double home = (data['homeAmount'] ?? 0).toDouble();
    double perService = (data['amountPerService'] ?? 1).toDouble();

    double total = truck + home;
    double servicesRemaining = total / perService;

    int critical = data['criticalServices'] ?? 5;
    int low = data['lowWarningServices'] ?? 7;

    Color statusColor = Colors.green;

    if (servicesRemaining <= critical) {
      statusColor = Colors.red;
    } else if (servicesRemaining <= low) {
      statusColor = Colors.orange;
    }

    Timestamp? updatedAt = data['updatedAt'];
    String updatedBy = data['updatedBy'] ?? "";

    String lastUpdated = updatedAt != null
        ? updatedAt.toDate().toLocal().toString()
        : "Unknown";

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['name'],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Truck: $truck"),
            Text("Home: $home"),
            Text("Total: $total"),
            Text("Services remaining: ${servicesRemaining.toStringAsFixed(1)}"),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => updateAmount(context, 'truckAmount', truck),
                  child: const Text("Edit Truck"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => updateAmount(context, 'homeAmount', home),
                  child: const Text("Edit Home"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Last updated: $lastUpdated by $updatedBy",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      color: statusColor.withOpacity(0.1),
    );
  }

  Future<void> updateAmount(
      BuildContext context, String field, double current) async {
    final controller =
        TextEditingController(text: current.toStringAsFixed(1));

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update amount"),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              double newValue =
                  double.tryParse(controller.text) ?? current;

              await doc.reference.update({
                field: newValue,
                'updatedAt': FieldValue.serverTimestamp(),
                'updatedBy': user.email,
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
}