import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/database_service.dart';
import '../../../utils/risk_calculator.dart';
import '../../../core/app_theme.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final DatabaseService _dbService = DatabaseService();
  Stream<List<Product>>? _productsStream;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  StreamSubscription<List<Product>>? _autoDonateSub;
  
  // Batch selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedProductIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null && _productsStream == null) {
      final rawStream = _dbService.streamStoreProducts(userId);
      _productsStream = rawStream.asBroadcastStream();

      // Silent Auto-Donate Tracker running over the stream
      _autoDonateSub = _productsStream!.listen((products) async {
        final prefs = await SharedPreferences.getInstance();
        final threshold = prefs.getDouble('auto_donation_threshold') ?? 25.0;
        
        for (var p in products) {
          if (p.status == 'active' && RiskCalculator.calculateProductLifePercentage(p) <= threshold) {
             _dbService.createDonation(p.id, p.storeOwnerId, requestType: 'donation');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _autoDonateSub?.cancel();
    super.dispose();
  }

  final List<String> _categories = ['All', 'Dairy', 'Produce', 'Meat', 'Bakery', 'Frozen', 'Beverages', 'Other'];

  void _toggleSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        if (_selectedProductIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedProductIds.add(productId);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _performBatchAction(String action) async {
    final count = _selectedProductIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Batch $action'),
        content: Text('Are you sure you want to mark $count items as $action?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: TextStyle(color: action == 'Delete' ? Colors.red : AppTheme.primaryColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (final id in _selectedProductIds) {
          if (action == 'Sold') {
            await _dbService.markProductSold(id);
          } else if (action == 'Donated') {
            final userId = context.read<AuthProvider>().user?.id;
            if (userId != null) await _dbService.createDonation(id, userId);
          } else if (action == 'Delete') {
            await _dbService.deleteProduct(id);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch $action completed for $count items')));
          _clearSelection();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showEditDialog(Product product) {
    final nameCtrl = TextEditingController(text: product.name);
    final qtyCtrl = TextEditingController(text: product.quantity.toString());
    final priceCtrl = TextEditingController(text: product.price.toString());
    final shelfCtrl = TextEditingController(text: product.shelfLifeDays?.toString() ?? '');
    final storageCtrl = TextEditingController(text: product.storageNo ?? '');
    String selectedCategory = product.category;
    
    if (!_categories.contains(selectedCategory) && selectedCategory != 'All') {
        selectedCategory = 'Other'; 
    } else if (selectedCategory == 'All') {
        selectedCategory = 'Produce';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Edit ${product.name}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textMainColor)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()),
                      items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) { if (v != null) setDialogState(() => selectedCategory = v); },
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity', isDense: true), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price', isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    const SizedBox(height: 12),
                    TextField(controller: storageCtrl, decoration: const InputDecoration(labelText: 'Storage Bin/No', isDense: true)),
                    const SizedBox(height: 12),
                    TextField(controller: shelfCtrl, decoration: const InputDecoration(labelText: 'Shelf Life (Days)', isDense: true), keyboardType: TextInputType.number),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondaryColor))),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _dbService.updateProduct(product.id, {
                        'name': nameCtrl.text,
                        'category': selectedCategory,
                        'quantity': int.tryParse(qtyCtrl.text) ?? product.quantity,
                        'price': double.tryParse(priceCtrl.text) ?? product.price,
                        'storage_no': storageCtrl.text.trim().isEmpty ? null : storageCtrl.text.trim(),
                        'shelf_life_days': int.tryParse(shelfCtrl.text),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully')));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: const Text('Save'),
                )
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildProductCard(Product product) {
    double lifePercent = RiskCalculator.calculateProductLifePercentage(product);
    Color riskColor = AppTheme.successColor;
    if (lifePercent <= 30) {
      riskColor = AppTheme.errorColor;
    } else if (lifePercent <= 60) riskColor = AppTheme.warningColor;

    final isSelected = _selectedProductIds.contains(product.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
        boxShadow: [
          BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onLongPress: () => _toggleSelection(product.id),
          onTap: _isSelectionMode ? () => _toggleSelection(product.id) : () => context.push('/product/${product.id}'),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(product.id),
                      activeColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textMainColor)),
                              const SizedBox(height: 4),
                              Text('${product.category} • ${product.quantity} items', 
                                style: GoogleFonts.inter(fontSize: 8, color: AppTheme.hintColor)
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  product.storageNo != null && product.storageNo!.isNotEmpty ? 'Bin ${product.storageNo}' : 'Unassigned',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              )
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${lifePercent.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: riskColor)),
                                    Text('${product.remainingShelfLife} days left', style: GoogleFonts.inter(fontSize: 8, color: AppTheme.hintColor)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                if (!_isSelectionMode)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: AppTheme.hintColor, size: 20),
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        _showEditDialog(product);
                                      } else if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Delete Product'),
                                            content: Text('Are you sure you want to delete ${product.name}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _dbService.deleteProduct(product.id);
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: _isSelectionMode 
          ? Text('${_selectedProductIds.length} selected', style: GoogleFonts.inter(color: AppTheme.textMainColor))
          : Text('Inventory', style: GoogleFonts.inter(color: AppTheme.textMainColor, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close, color: AppTheme.textMainColor), onPressed: _clearSelection)
          : null,
        actions: _isSelectionMode ? [
          IconButton(icon: const Icon(Icons.check_circle_outline, color: AppTheme.successColor), onPressed: () => _performBatchAction('Sold'), tooltip: 'Mark Sold'),
          IconButton(icon: const Icon(Icons.volunteer_activism_outlined, color: AppTheme.primaryColor), onPressed: () => _performBatchAction('Donated'), tooltip: 'Donate'),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor), onPressed: () => _performBatchAction('Delete'), tooltip: 'Delete'),
        ] : [],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.hintColor),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          onSelected: (v) => setState(() => _selectedCategory = cat),
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondaryColor),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200),
                          showCheckmark: false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _productsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }
                
                var products = snapshot.data ?? [];
                
                // Filter
                products = products.where((p) {
                  final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
                  return matchesSearch && matchesCat && p.status == 'active';
                }).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No active products found', style: GoogleFonts.inter(color: AppTheme.hintColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _buildProductCard(products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
