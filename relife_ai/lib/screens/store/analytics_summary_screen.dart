import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/database_service.dart';

class AnalyticsSummaryScreen extends StatefulWidget {
  final String userId;
  final String filterType; // 'all', 'donation', 'offer'

  const AnalyticsSummaryScreen({super.key, required this.userId, this.filterType = 'all'});

  @override
  State<AnalyticsSummaryScreen> createState() => _AnalyticsSummaryScreenState();
}

class _AnalyticsSummaryScreenState extends State<AnalyticsSummaryScreen> {
  final Set<String> _revokedIds = {};
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    String title = 'Pipeline & Summary Tracker';
    if (widget.filterType == 'donation') title = 'Donated Items';
    if (widget.filterType == 'offer') title = 'Discounted Items';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().streamDonationHistoryForStore(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading summary'));
          }

          final history = snapshot.data ?? [];
          
          List<Map<String, dynamic>> filteredItems = history.where((item) {
             // Instantly hide items that were revoked locally to prevent UI lag
             return !_revokedIds.contains(item['id'].toString());
          }).toList();

          if (widget.filterType == 'donation') {
            filteredItems = filteredItems.where((i) => i['request_type'] == 'donation' && i['status'] == 'completed').toList();
          } else if (widget.filterType == 'offer') {
            filteredItems = filteredItems.where((i) => i['request_type'] == 'offer' && i['status'] == 'completed').toList();
          }

          if (filteredItems.isEmpty) {
            return const Center(child: Text('No items to display.', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          final now = DateTime.now();
          
          List<Map<String, dynamic>> pending = [];
          List<Map<String, dynamic>> today = [];
          List<Map<String, dynamic>> weekly = [];
          List<Map<String, dynamic>> monthly = [];
          List<Map<String, dynamic>> yearly = [];

          for (var item in filteredItems) {
            if (item['status'] == 'pending' || item['status'] == 'claimed') {
              pending.add(item);
              continue;
            }

            final createdAt = DateTime.parse(item['created_at']);
            
            bool isToday = createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day;
            bool isWeekly = now.difference(createdAt).inDays <= 7;
            bool isMonthly = now.difference(createdAt).inDays <= 30;
            bool isYearly = createdAt.year == now.year;

            if (isToday) {
              today.add(item);
            } else if (isWeekly) {
              weekly.add(item);
            } else if (isMonthly) {
              monthly.add(item);
            } else if (isYearly) {
              yearly.add(item);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (pending.isNotEmpty) ...[
                _buildSectionTitle('Active Pipeline (Pending/Awaiting)', context, color: Colors.orange.shade800),
                ...pending.map((e) => _buildItemTile(e, context)),
                const SizedBox(height: 24),
              ],
              if (today.isNotEmpty) ...[
                _buildSectionTitle('Completed Today', context),
                ...today.map((e) => _buildItemTile(e, context)),
                const SizedBox(height: 24),
              ],
              if (weekly.isNotEmpty) ...[
                _buildSectionTitle('Completed This Week', context),
                ...weekly.map((e) => _buildItemTile(e, context)),
                const SizedBox(height: 24),
              ],
              if (monthly.isNotEmpty) ...[
                _buildSectionTitle('Completed This Month', context),
                ...monthly.map((e) => _buildItemTile(e, context)),
                const SizedBox(height: 24),
              ],
              if (yearly.isNotEmpty) ...[
                _buildSectionTitle('Completed This Year', context),
                ...yearly.map((e) => _buildItemTile(e, context)),
                const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color ?? Theme.of(context).primaryColor),
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> data, BuildContext context) {
    final donation = data;
    final productData = data['product'] is List ? (data['product'] as List).first : data['product'];
    final bool isDonation = donation['request_type'] == 'donation';
    final bool isActive = donation['status'] == 'pending' || donation['status'] == 'claimed';
    
    final dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(donation['created_at']));

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: Colors.orange.shade200, width: 2) : Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDonation ? Colors.blue.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDonation ? Icons.handshake : Icons.local_offer,
                    color: isDonation ? Colors.blue : Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${productData['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Qty: ${productData['quantity']} • ${isDonation ? "Donation" : "Discount"}', style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.orange : (isDonation ? Colors.blue : Colors.purple),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Pending' : (isDonation ? 'Donated' : 'Sold'),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            if (isActive) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Waiting for NGO to claim/complete.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontStyle: FontStyle.italic),
                    )
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleRevoke(donation['id'].toString(), productData['id']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12)
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Revoke', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _handleRevoke(String donationId, String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Do you want to revoke this item and place it back on the regular shelf?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes, Revoke'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await DatabaseService().revokeStoreRequest(productId);
        
        if (mounted) {
          setState(() {
            _revokedIds.add(donationId);
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item successfully revoked and restored.')));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
