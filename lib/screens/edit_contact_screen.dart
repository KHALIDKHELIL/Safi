import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_controller.dart';

class EditContactScreen extends ConsumerStatefulWidget {
  final Contact contact;
  const EditContactScreen({super.key, required this.contact});

  @override
  ConsumerState<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends ConsumerState<EditContactScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late int _selectedStars;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _phoneController = TextEditingController(text: widget.contact.phoneNumber ?? '');
    _selectedStars = widget.contact.trustScore;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final updatedContact = Contact(
        id: widget.contact.id,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        trustScore: _selectedStars,
      );
      
      await ref.read(contactControllerProvider).updateContact(updatedContact);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Trust Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          
          // Interactive Star Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                iconSize: 40,
                icon: Icon(
                  index < _selectedStars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() => _selectedStars = index + 1),
              );
            }),
          ),
          
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text('Save Profile', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}