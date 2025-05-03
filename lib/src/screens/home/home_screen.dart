import 'package:flutter/material.dart';
import 'package:tanari_app/src/screens/menu/acerca_app.dart';
import 'package:tanari_app/src/screens/menu/configuraciones_app.dart';
import 'package:tanari_app/src/screens/menu/historial_app.dart';
import 'package:tanari_app/src/screens/menu/ugv_tanari.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TANARI',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      drawer: _menuHome(context), // Pasar el contexto si es necesario
      backgroundColor: Colors.white,
      body: Container(),
    );
  }

  Drawer _menuHome(BuildContext context) => Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueGrey),
              accountName: const Text('Moises Rivera'),
              accountEmail: const Text('moiseselizerrivera@gmail.com'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                // foregroundImage: AssetImage(''), // Proporcionar la ruta de la imagen
                child: Icon(Icons.person,
                    size: 40, color: Colors.white), // Ejemplo de placeholder
              ),
            ),
            ListTile(
              leading: const Icon(Icons.car_rental),
              title: const Text('Modos de Operacion'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UgvTanari()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistorialApp()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ConfiguracionesApp()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Acerca de'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AcercaApp()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
}

class LedControlScreen {}
