import 'package:flutter/material.dart';

class ModoAcople extends StatefulWidget {
  const ModoAcople({super.key});

  @override
  State<ModoAcople> createState() => _ModoAcopleState();
}

class _ModoAcopleState extends State<ModoAcople> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Modo de Acople',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.lightGreenAccent,
      ),
      body: Column(
        children: [
          _monitoreoPanel(), // Llamado a la función corregida
          Container(
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
            height: 270,
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.blueAccent),
            child: const Text('Control UGV'),
          )
        ],
      ),
    );
  }

  // Corregido el nombre de la función a lowerCamelCase
  Widget _monitoreoPanel() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 430,
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.lightGreenAccent.shade100),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Monitoreo: ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _monitoreoCo2(), // Llamados a las funciones corregidas
          _monitoreoCh4(),
          _monitoreoTemperatura(),
          _monitoreoHumedad(),
        ],
      ),
    );
  }

  // Corregidos los nombres de las funciones a lowerCamelCase
  Widget _monitoreoCo2() {
    return Padding(
      // Eliminado const
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text(
            'CO2:    ',
            style: TextStyle(fontSize: 25),
          ),
          const SizedBox(
            //Espacio entre el texto y el contenedor
            width: 10,
          ),
          Expanded(
            child: //Usar Expanded para que el contenedor tome el ancho restante
                Container(
              height: 60,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.lightGreen),
              child: const Padding(
                //Eliminado const
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    '--  ppm',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _monitoreoCh4() {
    return Padding(
      // Eliminado const
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text(
            'CH4:    ',
            style: TextStyle(fontSize: 25),
          ),
          const SizedBox(
            //Espacio entre el texto y el contenedor
            width: 10,
          ),
          Expanded(
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.lightGreen),
              child: const Padding(
                //Eliminado const
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    '--  ppm',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _monitoreoTemperatura() {
    return Padding(
      // Eliminado const
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text(
            'Temp:  ',
            style: TextStyle(fontSize: 25),
          ),
          const SizedBox(
            //Espacio entre el texto y el contenedor
            width: 10,
          ),
          Expanded(
            child: Container(
              height: 60,
              width: 240,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.lightGreen),
              child: const Padding(
                //Eliminado const
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    '--  ºC',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _monitoreoHumedad() {
    return Padding(
      // Eliminado const
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text(
            'Hume:  ',
            style: TextStyle(fontSize: 25),
          ),
          const SizedBox(
            //Espacio entre el texto y el contenedor
            width: 10,
          ),
          Expanded(
              child: Container(
            height: 60,
            width: 240,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.lightGreen),
            child: const Padding(
              //Eliminado const
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '--  %',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
          ))
        ],
      ),
    );
  }
}
