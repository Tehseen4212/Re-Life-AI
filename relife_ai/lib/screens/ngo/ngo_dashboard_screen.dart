import 'package:flutter/material.dart';

class NGODashboardScreen extends StatelessWidget {
  const NGODashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NGO Dashboard')),
      body: const Center(child: Text('NGO Content Here')),
    );
  }
}
