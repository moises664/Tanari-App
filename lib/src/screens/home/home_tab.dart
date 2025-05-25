import 'package:flutter/material.dart';
import 'package:tanari_app/src/core/app_colors.dart'; // Asume que tienes este archivo

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary, // O el color que desees
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bienvenidos a',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightGreenAccent),
            ),
            Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('TANARI App',
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent)),
            ),
            SizedBox(height: 20),
            Text(
              'Esta es la vista de Home',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
