import 'package:flutter/material.dart';
import 'package:tanari_app/src/screens/menu/acerca_app.dart';
import 'package:tanari_app/src/screens/menu/configuraciones_app.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_Monitoreo.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_acople.dart';
import 'package:tanari_app/src/screens/menu/modos_operacion/modo_ugv.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TAnaRi',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      drawer: _menuHome(context), // Pasar el contexto si es necesario
      backgroundColor: Colors.white,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                'Bienvenidos a',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightGreenAccent),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('TANARI App',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Drawer _menuHome(BuildContext context) => Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              accountName: Text('Moises Rivera'),
              accountEmail: Text('moiseselizerrivera@gmail.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
            ExpansionTile(
              leading: const Icon(Icons.car_rental),
              title: const Text('Modos de Operacion'),
              children: <Widget>[
                ListTile(
                  title: const Text('Tanari DP'),
                  onTap: () {
                    // Navegar a la pantalla de Monitoreo
                    Navigator.pop(context); // Cierra el drawer
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ModoMonitoreo()));
                  },
                ),
                ListTile(
                  title: const Text('Tanari UGV'),
                  onTap: () {
                    // Navegar a la pantalla de Control UGV
                    Navigator.pop(context); // Cierra el drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ModoUgv()),
                    );
                  },
                ),
                ListTile(
                  title: const Text('Acople'),
                  onTap: () {
                    // Navegar a la pantalla de Acople
                    // Navigator.pop(context); // Cierra el drawer
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ModoAcople()));
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              children: <Widget>[
                ListTile(
                  title: const Text('Historial de Monitoreo'),
                  onTap: () {
                    // Navegar al historial de monitoreo
                    Navigator.pop(context); // Cierra el drawer
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const HistorialMonitoreoScreen()));
                  },
                ),
                ListTile(
                  title: const Text('Rutas'),
                  onTap: () {
                    // Navegar al historial de rutas
                    Navigator.pop(context); // Cierra el drawer
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const HistorialRutasScreen()));
                  },
                ),
                ListTile(
                  title: const Text('Ubicación'),
                  onTap: () {
                    // Navegar al historial de ubicación
                    Navigator.pop(context); // Cierra el drawer
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const HistorialUbicacionScreen()));
                  },
                ),
              ],
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
