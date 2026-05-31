import 'package:flutter/material.dart';

class StoreDashboardScreen extends StatelessWidget {
  const StoreDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Dashboard')),
      body: const Center(child: Text('Store Content Here')),
    );
  }
}
