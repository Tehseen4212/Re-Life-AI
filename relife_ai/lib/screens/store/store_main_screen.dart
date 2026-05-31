import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/donations_tab.dart';
import 'tabs/profile_tab.dart';
import '../../providers/auth_provider.dart';
import '../../services/brain_sync_service.dart';
import '../../services/database_service.dart';
import 'widgets/ai_assistant_bottom_sheet.dart';

class StoreMainScreen extends StatefulWidget {
  const StoreMainScreen({super.key});

  @override
  State<StoreMainScreen> createState() => _StoreMainScreenState();
}

class _StoreMainScreenState extends State<StoreMainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        BrainSyncService.instance.startSync(userId);
        DatabaseService().cleanupOldData(userId);
      }
    });
  }

  final List<Widget> _tabs = const [
    DashboardTab(),
    InventoryTab(),
    AnalyticsTab(),
    DonationsTab(),
    ProfileTab(),
  ];

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF9CA3AF),
            size: 24,
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                shape: BoxShape.circle,
              ),
            )
          else
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Crucial for floating navbar over background
      backgroundColor: const Color(0xFFF5F3FF),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 12, right: 12, bottom: 16),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
              _buildNavItem(1, Icons.inventory_2_rounded, 'Inventory'),
              _buildNavItem(2, Icons.pie_chart_rounded, 'Analytics'),
              _buildNavItem(3, Icons.handshake_rounded, 'Donations'),
              _buildNavItem(4, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 82), // Just above floating nav bar
        child: SizedBox(
          width: 50,
          height: 50,
          child: FloatingActionButton(
            shape: const CircleBorder(),
            elevation: 4,
            onPressed: () {
              final userId = context.read<AuthProvider>().user?.id;
              if (userId == null) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AIAssistantBottomSheet(userId: userId),
              );
            },
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF7C3AED)]),
              ),
              child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 24)),
            ),
          ),
        ),
      ),
    );
  }
}

