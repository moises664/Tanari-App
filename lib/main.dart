import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/screens/home/home_screen.dart';

const appTitle = 'TAnaRi';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(BleController());
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      home: HomeScreen(),
    );
  }
}
