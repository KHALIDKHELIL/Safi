import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_controller.dart';

class EditContactScreen extends ConsumerStatefulWidget {
  // Made optional. If null, the screen knows we are creating a NEW contact.
  final Contact? contact; 
  
  const EditContactScreen({super.key, this.contact});

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
    // Pre-fill if editing, leave blank if creating
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phoneNumber ?? '');
    _selectedStars = widget.contact?.trustScore ?? 5;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();

      if (widget.contact == null) {
        // CREATING NEW
        await ref.read(contactControllerProvider).createContact(name, phone, _selectedStars);
      } else {
        // UPDATING EXISTING
        final updatedContact = Contact(
          id: widget.contact!.id,
          name: name,
          phoneNumber: phone,
          trustScore: _selectedStars,
        );
        await ref.read(contactControllerProvider).updateContact(updatedContact);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProfile() async {
    if (widget.contact == null) return; // Cannot delete a contact that doesn't exist yet

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: const Text('Are you sure? This will remove them from your network.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(contactControllerProvider).deleteContact(widget.contact!.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = widget.contact == null;

    return Scaffold(
      // Dynamic title based on mode
      appBar: AppBar(title: Text(isCreating ? 'Add New Contact' : 'Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Trust Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          
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
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : Text(isCreating ? 'Create Profile' : 'Save Profile', style: const TextStyle(fontSize: 16)),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Only show the delete button if we are editing an existing profile!
          if (!isCreating)
            SizedBox(
              height: 50,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _isLoading ? null : _deleteProfile,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Contact', style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}