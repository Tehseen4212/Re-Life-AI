import 'package:flutter/material.dart';
import 'tabs/ngo_dashboard_tab.dart';
import 'tabs/ngo_requests_tab.dart';
import 'tabs/ngo_history_tab.dart';
import 'tabs/ngo_profile_tab.dart';

class NGOMainScreen extends StatefulWidget {
  const NGOMainScreen({super.key});

  @override
  State<NGOMainScreen> createState() => _NGOMainScreenState();
}

class _NGOMainScreenState extends State<NGOMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    NGODashboardTab(),
    NGORequestsTab(),
    NGOHistoryTab(),
    NGOProfileTab(),
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
      extendBody: true,
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
              _buildNavItem(1, Icons.list_alt_rounded, 'Requests'),
              _buildNavItem(2, Icons.history_rounded, 'History'),
              _buildNavItem(3, Icons.account_circle_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

