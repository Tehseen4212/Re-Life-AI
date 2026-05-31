import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _shelfLifeController = TextEditingController();
  final _priceController = TextEditingController();
  final _storageNoController = TextEditingController();
  
  DateTime? _mfgDate;
  DateTime? _expiryDate;

  String? _barcodeScanned;
  String _category = 'Produce';

  final List<String> _categories = [
    'Dairy', 'Produce', 'Meat', 'Meat & Seafood', 'Bakery', 'Medicine', 'Other',
    'Grains & Pulses', 'Beverages', 'Condiments & Spices', 'Snacks',
    'Frozen', 'Sweets & Mithai', 'Oils & Fats', 'Ready to Eat'
  ];
  bool _isLoading = false;

  // Dynamic ML CSV Dataset
  List<List<dynamic>> _csvData = [];

  @override
  void initState() {
    super.initState();
    _loadCSV();
    _nameController.addListener(() {
      final text = _nameController.text.trim().toLowerCase();
      if (text.length < 3) return; // Wait until 3 characters to start matching
      
      for (var row in _csvData) {
        if (row.length >= 3) {
          String prodName = row[0].toString().toLowerCase();
          if (prodName == text || prodName.startsWith(text)) {
            if (_shelfLifeController.text.isEmpty || _shelfLifeController.text != row[2].toString()) {
              _shelfLifeController.text = row[2].toString();
              if (row.length > 8) {
                _storageNoController.text = row[8].toString(); 
              }
              String cat = row[1].toString();
              if (_categories.contains(cat) && _category != cat) {
                 setState(() => _category = cat);
              }
            }
            break;
          }
        }
      }
    });
  }

  Future<void> _loadCSV() async {
    try {
      final rawData = await rootBundle.loadString("assets/data/shelf_life_dataset_large.csv");
      final lines = rawData.split('\n');
      List<List<dynamic>> listData = [];
      
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;
        
        if (line.startsWith('"')) {
           int endQuote = line.indexOf('"', 1);
           if (endQuote > 0) {
             String name = line.substring(1, endQuote);
             String rest = line.substring(endQuote + 2); // Skip ", "
             List<String> parts = rest.split(',');
             List<String> fullRow = [name, ...parts];
             if (fullRow.length >= 10) {
                listData.add(fullRow);
             }
           }
        } else {
           List<String> parts = line.split(',');
           if (parts.length >= 10) {
             listData.add(parts);
           }
        }
      }
      _csvData = listData;
    } catch (e) {
      debugPrint("CSV Load error: $e");
    }
  }

  Future<void> _fetchBarcodeData(String barcode) async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 1 && data['product'] != null) {
          final productName = data['product']['product_name'] ?? data['product']['generic_name'];
          if (productName != null) {
            _nameController.text = productName;
          }
        }
      }
    } catch (e) {
      debugPrint("Barcode Fetch Error: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _selectDate(BuildContext context, bool isMfg) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isMfg) {
          _mfgDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  var res = await Navigator.push(context, MaterialPageRoute(
                    // ignore: deprecated_member_use
                    builder: (context) => const SimpleBarcodeScannerPage(),
                  ));
                  if (res is String && res != '-1') {
                    setState(() => _barcodeScanned = res);
                    await _fetchBarcodeData(res);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_barcodeScanned != null ? 'Scanned: $_barcodeScanned' : 'Scan Barcode (Auto-fill)'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.fastfood)),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 16),
              if (['Dairy', 'Medicine', 'Meat', 'Meat & Seafood', 'Frozen'].contains(_category)) ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Mfg Date', prefixIcon: Icon(Icons.factory)),
                          child: Text(_mfgDate != null ? DateFormat('MMM d, yyyy').format(_mfgDate!) : 'Required', style: TextStyle(color: _mfgDate == null ? Colors.red : null)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Expiry Date', prefixIcon: Icon(Icons.event_busy)),
                          child: Text(_expiryDate != null ? DateFormat('MMM d, yyyy').format(_expiryDate!) : 'Required', style: TextStyle(color: _expiryDate == null ? Colors.red : null)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextFormField(
                  controller: _shelfLifeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Shelf Life (Days)', prefixIcon: Icon(Icons.calendar_today)),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers)),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _storageNoController,
                      decoration: const InputDecoration(labelText: 'Storage Bin/No', prefixIcon: Icon(Icons.shelves)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (in ₹, Optional)', prefixIcon: Icon(Icons.currency_rupee)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  if (_formKey.currentState!.validate() && userId != null) {
                    setState(() => _isLoading = true);
                    try {
                      final bool usesDates = ['Dairy', 'Medicine', 'Meat', 'Meat & Seafood', 'Frozen'].contains(_category);
                      if (usesDates && (_mfgDate == null || _expiryDate == null)) {
                        throw Exception('Manufacturing and Expiry Dates are strictly required for $_category.');
                      }
                      
                      await DatabaseService().addProduct({
                        'store_owner_id': userId,
                        'name': _nameController.text.trim(),
                        'category': _category,
                        'quantity': int.parse(_qtyController.text.trim()),
                        'shelf_life_days': usesDates ? null : int.parse(_shelfLifeController.text.trim()),
                        'storage_no': _storageNoController.text.trim().isEmpty ? null : _storageNoController.text.trim(),
                        'mfg_date': usesDates ? _mfgDate?.toIso8601String() : null,
                        'expiry_date': usesDates ? _expiryDate?.toIso8601String() : null,
                        'price': _priceController.text.trim().isEmpty ? 0.0 : double.parse(_priceController.text.trim()),
                        'barcode': _barcodeScanned,
                        'entry_date': DateTime.now().toIso8601String(),
                        'status': 'active'
                      });

                      // Match the AI Dataset for Storage Zone Advice
                      List<dynamic>? matchedRow;
                      final saveText = _nameController.text.trim().toLowerCase();
                      for (var row in _csvData) {
                         if (row[0].toString().toLowerCase() == saveText || row[0].toString().toLowerCase().startsWith(saveText)) {
                            matchedRow = row;
                            break;
                         }
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product Added Successfully')));
                        
                        if (matchedRow != null && matchedRow.length >= 10) {
                           showDialog(
                             context: context,
                             barrierDismissible: false,
                             builder: (dialogCtx) => AlertDialog(
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                               icon: const Icon(Icons.shelves, size: 40, color: Colors.blue),
                               title: const Text('Storage Advice', style: TextStyle(fontWeight: FontWeight.bold)),
                               content: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text('To maximize shelf life, keep this in:', style: TextStyle(color: Colors.grey.shade700)),
                                   const SizedBox(height: 8),
                                   Text(matchedRow![7].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                   const SizedBox(height: 16),
                                   Row(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                       const SizedBox(width: 8),
                                       Expanded(child: Text(matchedRow[9].toString(), style: TextStyle(color: Colors.grey.shade800, fontSize: 14))),
                                     ],
                                   ),
                                 ],
                               ),
                               actions: [
                                 ElevatedButton(
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                   onPressed: () {
                                     Navigator.pop(dialogCtx);
                                     context.pop(); // Pop back to dashboard
                                   },
                                   child: const Text('OK, Got it'),
                                 )
                               ],
                             )
                           );
                        } else {
                           context.pop(); // No advice found, directly pop to dashboard
                        }
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                    setState(() => _isLoading = false);
                  }
                },
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Product'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
