import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';
import '../../../utils/risk_calculator.dart';
import '../../../core/app_theme.dart';
import '../../../services/brain_sync_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final DatabaseService _dbService = DatabaseService();
  Stream<List<Product>>? _productsStream;
  List<Product>? _fastProducts;
  bool _isFastFetching = false;
  Set<String> _ignoredDonations = {};

  @override
  void initState() {
    super.initState();
    _loadIgnoredDonations();
  }

  Future<void> _loadIgnoredDonations() async {
    final prefs = await SharedPreferences.getInstance();
    if(mounted) {
      setState(() {
        _ignoredDonations = (prefs.getStringList('ignored_donations') ?? []).toSet();
      });
    }
  }

  Future<void> _ignoreDonation(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ignoredDonations.add(productId);
    });
    await prefs.setStringList('ignored_donations', _ignoredDonations.toList());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user;
    final userId = user?.id;
    if (userId != null && _productsStream == null) {
      _productsStream = _dbService.streamStoreProducts(userId);
      if (!_isFastFetching) {
        _isFastFetching = true;
        _dbService.getStoreProductsFast(userId).then((list) {
          if (mounted) setState(() => _fastProducts = list);
        });
        _dbService.getNotificationsFast(userId).then((list) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _showNotifications(String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Notifications', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textMainColor)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _dbService.streamNotifications(userId),
                  initialData: DatabaseService.cachedGlobalNotifications,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                    }
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final notes = DatabaseService.cachedGlobalNotifications ?? snapshot.data ?? [];
                    if (notes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('All caught up!', style: GoogleFonts.inter(color: AppTheme.hintColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Dismissible(
                          key: Key(note['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Colors.red,
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            _dbService.deleteNotification(note['id']);
                            setState(() {}); // Instant red dot UI repaint
                          },
                          child: ListTile(
                            onTap: () {
                              _dbService.markNotificationRead(note['id']);
                              setState(() {}); // Instant red dot UI repaint
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: note['is_read'] ? Colors.grey[100] : AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                note['type'] == 'CLAIM' ? Icons.handshake_rounded : Icons.warning_amber_rounded,
                                color: note['is_read'] ? Colors.grey : AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            title: Text(note['title'], style: GoogleFonts.inter(fontSize: 14, fontWeight: note['is_read'] ? FontWeight.normal : FontWeight.w800)),
                            subtitle: Text(note['message'], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryColor)),
                            trailing: !note['is_read'] ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)) : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskTile(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text('$value', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessTracker(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF9CA3AF), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    double lifePercent = RiskCalculator.calculateProductLifePercentage(product);
    Color riskColor = AppTheme.successColor;
    if (lifePercent <= 30) {
      riskColor = AppTheme.errorColor;
    } else if (lifePercent <= 60) riskColor = AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/product/${product.id}'),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textMainColor)),
                              const SizedBox(height: 2),
                              Text('${product.category.toUpperCase()} • BIN ${product.storeOwnerId.substring(0,3).toUpperCase()}', 
                                style: GoogleFonts.inter(fontSize: 9, color: AppTheme.hintColor, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${lifePercent.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: riskColor)),
                            Text('${product.remainingShelfLife} days left', style: GoogleFonts.inter(fontSize: 8, color: AppTheme.textSecondaryColor)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: riskColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                RiskCalculator.getRiskClassification(((100.0 - lifePercent) / 100.0)).toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final userId = user?.id;
    if (userId == null) return const Center(child: Text('Not Logged In'));

    // Prefer store name from profile object, fallback to legacy metadata
    final profile = context.watch<AuthProvider>().profile;
    final storeName = (profile?.storeName != null && profile!.storeName!.isNotEmpty) 
        ? profile.storeName! 
        : (user?.userMetadata?['store_name'] ?? 'Store Owner');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _productsStream == null 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<List<Product>>(
            stream: _productsStream,
            initialData: DatabaseService.cachedGlobalProducts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && _fastProducts == null) {
                return const Center(child: CircularProgressIndicator());
              }
              
              var productsRaw = snapshot.data ?? _fastProducts ?? [];
              final cutoff = DateTime.now().subtract(const Duration(days: 3));
              
              // Filter out old inactive items from UI as a fail-safe
              productsRaw = productsRaw.where((p) {
                if (p.status == 'active') return true;
                return p.entryDate.isAfter(cutoff);
              }).toList();

              final products = productsRaw.where((p) => p.status != 'sold').toList();
              final allSaved = productsRaw.where((p) => p.status == 'sold' || p.status == 'donated' || p.status == 'offered').toList();
              
              double totalSavedKg = 0;
              for(var p in allSaved) {
                totalSavedKg += p.quantity;
              }
              
              final lowRisk = products.where((p) => RiskCalculator.calculateProductLifePercentage(p) > 60).length;
              final mediumRisk = products.where((p) => RiskCalculator.calculateProductLifePercentage(p) > 30 && RiskCalculator.calculateProductLifePercentage(p) <= 60).length;
              final highRisk = products.where((p) => RiskCalculator.calculateProductLifePercentage(p) <= 30).length;

              double totalValue = 0;
              for (var p in products) { totalValue += p.price * p.quantity; }
              int itemsSaved = allSaved.length;
              double moneyLost = 0;
              for (var p in products) {
                if (p.remainingShelfLife <= 0 && p.status == 'active') moneyLost += p.price * p.quantity;
              }

              final autoSuggestList = products.where((p) {
                if (p.status != 'active' || _ignoredDonations.contains(p.id)) return false;
                final bool isDying = RiskCalculator.calculateProductLifePercentage(p) <= 30;
                final bool isExpiringSoon = p.remainingShelfLife <= 2 && p.remainingShelfLife >= 0;
                return isDying || isExpiringSoon;
              }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120), // Clearance for FABs
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Welcome,', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFC4B5FD))),
                                  Text(storeName, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                                ],
                              ),
                              StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _dbService.streamNotifications(userId),
                                initialData: DatabaseService.cachedGlobalNotifications,
                                builder: (context, snapshot) {
                                  final currentNotes = DatabaseService.cachedGlobalNotifications ?? snapshot.data ?? [];
                                  final hasUnread = currentNotes.any((n) => n['is_read'] == false);
                                  return Stack(
                                    children: [
                                      IconButton(
                                        onPressed: () => _showNotifications(userId),
                                        icon: const Icon(Icons.notifications_none, color: Colors.white),
                                      ),
                                      if (hasUnread)
                                        Positioned(
                                          right: 12,
                                          top: 12,
                                          child: Container(
                                            width: 8, height: 8,
                                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          ),
                                        )
                                    ],
                                  );
                                }
                              )
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOTAL ITEMS TRACKED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFC4B5FD), letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${products.length}', style: GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white)),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Text('items in inventory', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFC4B5FD))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.successColor, borderRadius: BorderRadius.circular(99)),
                                      child: Text('${totalSavedKg.toStringAsFixed(0)} kg saved', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                                      child: Row(
                                        children: [
                                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.successColor, shape: BoxShape.circle)),
                                          const SizedBox(width: 4),
                                          Text('System Active', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ],
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RISK OVERVIEW', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 0.8)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildRiskTile('LOW RISK', lowRisk, AppTheme.successColor),
                              _buildRiskTile('MED RISK', mediumRisk, AppTheme.warningColor),
                              _buildRiskTile('HIGH RISK', highRisk, AppTheme.errorColor),
                            ],
                          ),
                          const SizedBox(height: 32),
                          
                          Text('BUSINESS TRACKER', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 0.8)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildBusinessTracker('INVENTORY\nVALUE', '₹${totalValue.toStringAsFixed(0)}', AppTheme.textMainColor),
                              _buildBusinessTracker('ITEMS\nSAVED', '$itemsSaved', AppTheme.successColor),
                              _buildBusinessTracker('MONEY\nLOST', '₹${moneyLost.toStringAsFixed(0)}', AppTheme.errorColor),
                            ],
                          ),
                          const SizedBox(height: 32),

                          if (autoSuggestList.isNotEmpty) ...[
                            Text('AUTO SUGGESTIONS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 0.8)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 140,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: autoSuggestList.length,
                                itemBuilder: (context, index) {
                                  final p = autoSuggestList[index];
                                  final life = RiskCalculator.calculateProductLifePercentage(p);
                                  return Container(
                                    width: 220,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                                      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppTheme.textMainColor), overflow: TextOverflow.ellipsis)),
                                            InkWell(onTap: () => _ignoreDonation(p.id), child: const Icon(Icons.close, size: 16, color: AppTheme.hintColor)),
                                          ]
                                        ),
                                        const Spacer(),
                                        Text('${p.quantity} kg • ${life.toStringAsFixed(0)}% Life Left', style: GoogleFonts.inter(color: AppTheme.warningColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.warningColor, 
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(double.infinity, 36),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                            ),
                                            onPressed: () async {
                                              await _dbService.createDonation(p.id, p.storeOwnerId);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to donations')));
                                              }
                                            },
                                            child: Text('Donate Now', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                          )
                                        )
                                      ]
                                    )
                                  );
                                }
                              )
                            ),
                            const SizedBox(height: 32),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('LIVE FEED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.hintColor, letterSpacing: 0.8)),
                              InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Syncing hardware & cleaning up history...'),
                                      duration: Duration(seconds: 1),
                                      backgroundColor: AppTheme.primaryColor,
                                    )
                                  );
                                  // Refresh data
                                  _dbService.cleanupOldData(userId);
                                  BrainSyncService.instance.startSync(userId);
                                  setState(() {
                                    _productsStream = _dbService.streamStoreProducts(userId);
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text('Sync ↺', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (products.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('No products tracked yet.', style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                return _buildProductCard(products[index]);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
