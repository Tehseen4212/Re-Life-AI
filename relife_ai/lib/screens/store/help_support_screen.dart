import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.help_outline, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            Text('Need Assistance?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'If you are an NGO experiencing issues with a Store Owner (e.g. scams, unresponsive behavior, or fake donations), please report them directly to the Developer team. We will review the account and ban them immediately upon confirmation.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report a Store 🚨', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Developer Contact: relife_ai.help@gmail.com', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Phone: +1 800-RELIFE-AI'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text('Store Profile Config', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Store Owners: Please ensure your "Settings -> Edit Profile" is fully filled with your authentic Phone Number and Maps URL so NGOs can easily route directly to your business to collect Donations.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
