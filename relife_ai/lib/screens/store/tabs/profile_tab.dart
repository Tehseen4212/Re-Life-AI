import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/app_theme.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  double _donationThreshold = 25.0;

  @override
  void initState() {
    super.initState();
    _loadThreshold();
  }

  Future<void> _loadThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _donationThreshold = prefs.getDouble('auto_donation_threshold') ?? 25.0;
    });
  }

  Future<void> _saveThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('auto_donation_threshold', value);
    setState(() {
      _donationThreshold = value;
    });
  }

  void _showThresholdDialog() {
    double tempValue = _donationThreshold;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Auto-Donation Threshold', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Items will be automatically donated when their life percentage falls below:', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 24),
              Text('${tempValue.toInt()}%', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
              Slider(
                value: tempValue,
                min: 5,
                max: 50,
                divisions: 9,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) => setDialogState(() => tempValue = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('5%', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.hintColor)),
                  Text('50%', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.hintColor)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                _saveThreshold(tempValue);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Threshold updated successfully')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Upper Purple Gradient Header
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Text('Store Profile', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                // Overlaying Avatar
                Positioned(
                  bottom: -50,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.storefront_rounded, size: 50, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60), // Spacing for overlapping avatar
            
            // Profile details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    profile?.storeName?.isNotEmpty == true ? profile!.storeName! : 'Complete Store Profile', 
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textMainColor)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.locationAddress?.isNotEmpty == true ? profile!.locationAddress! : (profile?.email ?? 'Unknown Email'), 
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondaryColor)
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(99)),
                    child: Text('Store Owner', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 40),
                  
                  // Settings List
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ]
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.backgroundColor, shape: BoxShape.circle),
                            child: const Icon(Icons.settings, color: AppTheme.primaryColor, size: 20)
                          ),
                          title: Text('Settings (Edit Profile)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMainColor)),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.hintColor),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                          onTap: () => context.push('/store/profile/edit'),
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.backgroundColor, shape: BoxShape.circle),
                            child: const Icon(Icons.volunteer_activism, color: AppTheme.primaryColor, size: 20)
                          ),
                          title: Text('Auto-Donation Threshold', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMainColor)),
                          subtitle: Text('Currently set to ${_donationThreshold.toInt()}%', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor)),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.hintColor),
                          onTap: _showThresholdDialog,
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppTheme.backgroundColor, shape: BoxShape.circle),
                            child: const Icon(Icons.help_outline, color: AppTheme.primaryColor, size: 20)
                          ),
                          title: Text('Help & Support', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMainColor)),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.hintColor),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                          onTap: () => context.push('/store/support'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.read<AuthProvider>().signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, color: AppTheme.errorColor, size: 20),
                      label: Text('Logout', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECACA), width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: const Color(0xFFFEF2F2),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Clearance for navbar
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
