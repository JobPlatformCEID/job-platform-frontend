import 'package:flutter/material.dart';
import '../services/api_serv.dart';
import 'emp_home.dart';

class EmployerProfileSetupScreen extends StatefulWidget {
  const EmployerProfileSetupScreen({super.key});

  @override
  State<EmployerProfileSetupScreen> createState() => _EmployerProfileSetupState();
}

class _EmployerProfileSetupState extends State<EmployerProfileSetupScreen> {
  final _companyNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    if (_companyNameController.text.isEmpty) {
      _showErrorDialog('Company name is required.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.updateEmployerProfile({
        'company_name': _companyNameController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'website': _websiteController.text,
      });

      if (response.statusCode == 200 && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmployerHomeScreen()),
        );
      } else {
        _showErrorDialog('Failed to save profile. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Company Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set up your company profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Candidates will see this information.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _companyNameController,
              decoration: _decoration('Company Name *', Icons.business),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _decoration('Company Description', Icons.edit_note),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _locationController,
              decoration: _decoration('Location (e.g. Athens, Greece)', Icons.location_on_outlined),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              decoration: _decoration('Website (e.g. https://company.com)', Icons.language),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SAVE & CONTINUE',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const EmployerHomeScreen()),
              ),
              child: const Text('Skip for now',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }
}
