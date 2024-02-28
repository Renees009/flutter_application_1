import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:get_it/get_it.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton(() => MyAppState());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  setupLocator(); // Initialize the service locator

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namer App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 63, 219, 73)),
      ),
      home: MyHomePage(),
    );
  }
}

class MyAppState extends ChangeNotifier {
  MyAppState() {
    print('MyAppState Constructor');
    fetchCounterFromFirestore();
    setupLocaldb();
    listenToFirestoreCounter();
  }

  final StreamController<int> _counterStreamController =
      StreamController<int>.broadcast();

  Stream<int> get counterStream => _counterStreamController.stream;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  late Box counterBox;
  var current = WordPair.random();
  // var box = await Hive.openBox('testBox');

  int count = 0;
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

  var favorites = <WordPair>[];
  var favoritesCount = <WordPair, int>{}; // New map to track likes count

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
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: constraints.maxWidth >= 600,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite),
                    label: Text('Favorites'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = locator<MyAppState>();
    var pair = appState.current;
    var count = appState.count;
    var color;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    if (count.isEven) {
      color = Colors.purple;
    } else {
      color = Colors.orange;
    }
    print(count.toString());
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(pair: pair),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(
                  icon,
                  color: color,
                ),
                label: Text(
                  'Like',
                  style: TextStyle(
                    color: count.isEven
                        ? Colors.purple
                        : Colors.orange, // Change colour based on count
                  ),
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: StreamBuilder<int>(
                  stream: appState.counterStream,
                  builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                    if (snapshot.hasData) {
                      return Text('Next - ${snapshot.data}');
                    } else {
                      return CircularProgressIndicator.adaptive();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.pair,
  });

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          pair.asLowerCase,
          style: style,
          semanticsLabel: "${pair.first} ${pair.second}",
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.'),
      );
    }

    return ListView.builder(
      itemCount: appState.favorites.length,
      itemBuilder: (context, index) {
        var pair = appState.favorites[index];
        var likesCount =
            appState.favoritesCount[pair] ?? 0; // Get the count for this pair

        var isEvenCount = likesCount.isEven;
        var heartIconColor = isEvenCount ? Colors.purple : Colors.orange;

        return ListTile(
          leading: Icon(
            Icons.favorite,
            color: heartIconColor,
          ),
          title: Text(pair.asLowerCase),
          trailing: Text('$likesCount'), // Display the likes count
        );
      },
    );
  }
}
