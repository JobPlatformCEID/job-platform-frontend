import 'package:flutter/material.dart';
import '../services/api_serv.dart';
import 'cand_home.dart';

class CandidateProfileSetupScreen extends StatefulWidget {
  const CandidateProfileSetupScreen({super.key});

  @override
  State<CandidateProfileSetupScreen> createState() => _CandidateProfileSetupState();
}

class _CandidateProfileSetupState extends State<CandidateProfileSetupScreen> {
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.updateCandidateProfile({
        'phone': _phoneController.text,
        'location': _locationController.text,
        'bio': _bioController.text,
      });

      if (response.statusCode == 200 && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
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
        title: const Text('Complete Your Profile'),
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
              'Tell us about yourself',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You can update this later from your profile.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _decoration('Phone Number', Icons.phone_outlined),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _locationController,
              decoration: _decoration('Location (e.g. Athens, Greece)', Icons.location_on_outlined),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: _decoration('Bio / About Me', Icons.edit_note),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
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
                MaterialPageRoute(builder: (_) => const CandidateHomeScreen()),
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
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}