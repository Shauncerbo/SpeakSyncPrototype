import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpeakSync Dashboard'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Welcome to your Dashboard!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('You have successfully logged in.'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Log out and go back to login screen
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('Log Out'),
            )
          ],
        ),
      ),
    );
  }
}