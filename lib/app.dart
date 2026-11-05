import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Hide & Hunt',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff345e43)),
      useMaterial3: true,
    ),
    home: const Home(),
  );
}
