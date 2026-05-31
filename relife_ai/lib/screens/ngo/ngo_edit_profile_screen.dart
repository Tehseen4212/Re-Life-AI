import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class NGOEditProfileScreen extends StatefulWidget {
  const NGOEditProfileScreen({super.key});

  @override
  State<NGOEditProfileScreen> createState() => _NGOEditProfileScreenState();
}

class _NGOEditProfileScreenState extends State<NGOEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _mapUrlController;
  late TextEditingController _aboutController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _nameController = TextEditingController(text: profile?.storeName ?? '');
    _phoneController = TextEditingController(text: profile?.contactNumber ?? '');
    _addressController = TextEditingController(text: profile?.locationAddress ?? '');
    _mapUrlController = TextEditingController(text: profile?.googleMapUrl ?? '');
    _aboutController = TextEditingController(text: profile?.aboutStore ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit NGO Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'NGO Name', prefixIcon: Icon(Icons.business)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Contact Number', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Headquarters Address', prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mapUrlController,
                decoration: const InputDecoration(labelText: 'Google Map Link (Optional)', prefixIcon: Icon(Icons.map)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aboutController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'About NGO', prefixIcon: Icon(Icons.info_outline)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  if (_formKey.currentState!.validate() && userId != null) {
                    setState(() => _isLoading = true);
                    try {
                      await DatabaseService().updateUserProfile(userId, {
                        'store_name': _nameController.text.trim(), // reusing the same DB column
                        'contact_number': _phoneController.text.trim(),
                        'location_address': _addressController.text.trim(),
                        'google_map_url': _mapUrlController.text.trim(),
                        'about_store': _aboutController.text.trim(),
                      });
                      
                      // Refresh profile within the provider
                      if (context.mounted) {
                        await context.read<AuthProvider>().fetchProfile(); 
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated')));
                          context.pop();
                        }
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                    setState(() => _isLoading = false);
                  }
                },
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
