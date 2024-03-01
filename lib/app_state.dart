import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart';
import 'package:hive/hive.dart';
import 'package:namer_app/locator.dart';

class MyAppState {
  final StreamController<int> _counterStreamController =
      StreamController<int>.broadcast();

  Stream<int> get counterStream => _counterStreamController.stream;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Box counterBox;
  var current = WordPair.random();
  int count = 0;
  var favorites = <WordPair>[];
  var favoritesCount = <WordPair, int>{};

  MyAppState() {
    print('MyAppState Constructor');
    fetchCounterFromFirestore();
    setupLocaldb();
    listenToFirestoreCounter();
  }

  Future<void> updateCounterInFirestore() async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction
            .get(_firestore.collection('counters').doc('counterDoc'));
        if (snapshot.exists) {
          int currentCount =
              (snapshot.data() as Map<String, dynamic>)?['count'] ?? 0;

          transaction.update(
              _firestore.collection('counters').doc('counterDoc'),
              {'count': currentCount + 1});
          print('Counter updated in Firestore');
        } else {
          print('No counter document found in Firestore');
        }
      });
    } catch (e) {
      print('Failed to update counter in Firestore: $e');
    }
  }

  Future<void> fetchCounterFromFirestore() async {
    try {
      DocumentSnapshot docSnapshot =
          await _firestore.collection('counters').doc('counterDoc').get();

      if (docSnapshot.exists) {
        count = (docSnapshot.data() as Map<String, dynamic>)?['count'] ?? 0;
        notifyListeners();
        print('Counter fetched from Firestore: $count');
      } else {
        print('No counter document found in Firestore');
      }
    } catch (e) {
      print('Failed to fetch counter from Firestore: $e');
    }
  }

  void listenToFirestoreCounter() {
    _firestore
        .collection('counters')
        .doc('counterDoc')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        int newCount = snapshot.data()?['count'] ?? 0;
        _counterStreamController.add(newCount);
      }
    });
  }

  void setupLocaldb() async {
    counterBox = await Hive.openBox('counterBox');
    if (counterBox.isEmpty) {
      print('counter empty');
      count = 0;
    } else {
      print('else');
      print(count.toString());
    }
  }

  Future<int> getCounterFuture() async {
    counterBox = await Hive.openBox('counterBox');
    try {
      DocumentSnapshot docSnapshot =
          await _firestore.collection('counters').doc('counterDoc').get();

      if (docSnapshot.exists) {
        count = (docSnapshot.data() as Map<String, dynamic>)?['count'] ?? 0;

        print('Counter fetched from Firestore: $count');
      } else {
        print('No counter document found in Firestore');
      }
    } catch (e) {
      print('Failed to fetch counter from Firestore: $e');
    }

    return count;
  }

  void getNext() {
    current = WordPair.random();
    count += 1;
    counterBox.put('counter', count);
    updateCounterInFirestore();
    notifyListeners();
  }

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
      favoritesCount.remove(current);
    } else {
      favorites.add(current);
      favoritesCount[current] = count; // Increment the count
    }
    notifyListeners();
  }

  void notifyListeners() {
    _counterStreamController.add(count);
  }
}

class Locator {
  static void setupLocator() {
    locator.registerSingleton<MyAppState>(MyAppState());
  }
}
