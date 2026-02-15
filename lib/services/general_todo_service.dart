import 'package:cloud_firestore/cloud_firestore.dart';

class GeneralTodoService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _todosCollection =>
      _db.collection('serviceGeneralTodos');

  Stream<QuerySnapshot> getTodosStream() {
    return _todosCollection.orderBy('createdAt', descending: false).snapshots();
  }

  Future<void> addTodo(String title, String note) async {
    await _todosCollection.add({
      'title': title,
      'note': note,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleTodo(String id, bool completed) async {
    await _todosCollection.doc(id).update({
      'completed': completed,
    });
  }

  Future<void> updateTodo(String id, String title, String note) async {
    await _todosCollection.doc(id).update({
      'title': title,
      'note': note,
    });
  }

  Future<void> deleteTodo(String id) async {
    await _todosCollection.doc(id).delete();
  }
}
