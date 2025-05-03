import 'package:flutter/material.dart';
import 'package:tanari_app/src/screens/menu/acerca_app.dart';
import 'package:tanari_app/src/screens/menu/configuraciones_app.dart';
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
                  title: const Text('Monitoreo del Dispositivo Portatil'),
                  onTap: () {
                    // Navegar a la pantalla de Monitoreo
                    Navigator.pop(context); // Cierra el drawer
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const MonitoreoScreen()));
                  },
                ),
                ListTile(
                  title: const Text('Control UGV'),
                  onTap: () {
                    // Navegar a la pantalla de Control UGV
                    Navigator.pop(context); // Cierra el drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UgvTanari()),
                    );
                  },
                ),
                ListTile(
                  title: const Text('Acople'),
                  onTap: () {
                    // Navegar a la pantalla de Acople
                    Navigator.pop(context); // Cierra el drawer
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const AcopleScreen()));
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
