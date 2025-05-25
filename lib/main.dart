// main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // <--- ¡Asegúrate de importar GetX!
import 'package:logging/logging.dart';
import 'package:tanari_app/src/controllers/bluetooth/ble.controller.dart';
import 'package:tanari_app/src/screens/login/welcome_screen.dart';

const appTitle = 'TAnaRi';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización controlada de controladores
  await _initializeApp();

  runApp(const MyApp());
}

final _logger = Logger('Main');

Future<void> _initializeApp() async {
  try {
    await Get.putAsync<BleController>(() async => BleController());
  } catch (e) {
    _logger.severe('Error initializing controllers', e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // <--- ¡CAMBIADO A GETMATERIALAPP!
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const WelcomeScreen(),
      // Pantalla de carga inicial
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
