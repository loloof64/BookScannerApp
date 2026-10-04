import 'package:book_scanner_app/screens/books_list_screen.dart';
import 'package:flutter/material.dart';

void main() async {
  // Required before initializing native plugins or async code in main
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // BookListScreen becomes the main landing screen
      home: const BookListScreen(),
    );
  }
}
