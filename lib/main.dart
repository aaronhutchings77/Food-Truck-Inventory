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
        return MainScreen(user: snapshot.data!);
      },
    );
  }
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
  Future<void> signIn() async {
    await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
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

/* ===================== MAIN SCREEN ===================== */

class MainScreen extends StatefulWidget {
  final User user;
  const MainScreen({super.key, required this.user});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? "Inventory" : "Shopping"),
        actions: [
          if (index == 0)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () =>
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => AddItemScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async =>
                FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: index == 0
          ? InventoryScreen(user: widget.user)
          : ShoppingScreen(user: widget.user),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (v) => setState(() => index = v),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory), label: "Inventory"),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: "Shopping"),
        ],
      ),
    );
  }
}

/* ===================== ADD ITEM ===================== */

class AddItemScreen extends StatelessWidget {
  final nameController = TextEditingController();
  final perServiceController = TextEditingController();
  final criticalController = TextEditingController();
  final lowController = TextEditingController();
  final bufferController = TextEditingController();

  AddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Item")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            textField("Name", nameController),
            textField("Amount Per Service", perServiceController),
            textField("Critical Services", criticalController),
            textField("Low Warning Services", lowController),
            textField("Desired Buffer Services", bufferController),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () async {
                await FirebaseFirestore.instance.collection("items").add({
                  "name": nameController.text,
                  "amountPerService":
                      double.parse(perServiceController.text),
                  "truckAmount": 0.0,
                  "homeAmount": 0.0,
                  "criticalServices":
                      int.parse(criticalController.text),
                  "lowWarningServices":
                      int.parse(lowController.text),
                  "desiredBufferServices":
                      int.parse(bufferController.text),
                  "updatedAt": FieldValue.serverTimestamp(),
                  "updatedBy":
                      FirebaseAuth.instance.currentUser!.email,
                });
                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }

  Widget textField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}

/* ===================== INVENTORY ===================== */

class InventoryScreen extends StatelessWidget {
  final User user;
  const InventoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("items").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        List<QueryDocumentSnapshot> critical = [];
        List<QueryDocumentSnapshot> low = [];
        List<QueryDocumentSnapshot> good = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          double total = (data["truckAmount"] ?? 0) +
              (data["homeAmount"] ?? 0);
          double per = data["amountPerService"];
          double services = total / per;

          if (services <= data["criticalServices"]) {
            critical.add(doc);
          } else if (services <=
              data["lowWarningServices"]) {
            low.add(doc);
          } else {
            good.add(doc);
          }
        }

        return ListView(
          children: [
            section("🚨 Critical", critical, user, Colors.red),
            section("⚠️ Low", low, user, Colors.orange),
            section("✅ Good", good, user, Colors.green),
          ],
        );
      },
    );
  }

  Widget section(String title, List docs, User user, Color color) {
    if (docs.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.all(10),
            child: Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color))),
        ...docs.map((doc) => ItemCard(doc: doc, user: user))
      ],
    );
  }
}

/* ===================== SHOPPING ===================== */

class ShoppingScreen extends StatelessWidget {
  final User user;
  const ShoppingScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("items").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          double total = (data["truckAmount"] ?? 0) +
              (data["homeAmount"] ?? 0);
          return total / data["amountPerService"] <=
              data["lowWarningServices"];
        }).toList();

        if (docs.isEmpty) {
          return const Center(
              child: Text("Nothing needs restocking."));
        }

        return ListView(
          children:
              docs.map((doc) => ShoppingCard(doc: doc)).toList(),
        );
      },
    );
  }
}

/* ===================== ITEM CARD ===================== */

class ItemCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final User user;
  const ItemCard({super.key, required this.doc, required this.user});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    double truck = data["truckAmount"];
    double home = data["homeAmount"];
    double per = data["amountPerService"];
    double services = (truck + home) / per;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(data["name"]),
        subtitle: Text(
            "Truck: $truck | Home: $home\nServices: ${services.toStringAsFixed(1)}"),
        onTap: () => editItem(context),
      ),
    );
  }

  void editItem(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => const AlertDialog(
              content:
                  Text("Advanced editing screen coming next."),
            ));
  }
}

/* ===================== SHOPPING CARD ===================== */

class ShoppingCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const ShoppingCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    double total =
        data["truckAmount"] + data["homeAmount"];
    double per = data["amountPerService"];
    int buffer = data["desiredBufferServices"];

    double target = per * buffer;
    double suggested = target - total;
    if (suggested < 0) suggested = 0;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(data["name"]),
        subtitle:
            Text("Suggested Buy: ${suggested.toStringAsFixed(1)}"),
      ),
    );
  }
}