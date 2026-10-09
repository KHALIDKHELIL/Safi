import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Needed for kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/loan_model.dart';
import '../models/contact_model.dart';
import '../providers/loan_controller.dart';
import '../providers/database_providers.dart';

class NewLogSheet extends ConsumerStatefulWidget {
  const NewLogSheet({super.key});

  @override
  ConsumerState<NewLogSheet> createState() => _NewLogSheetState();
}

class _NewLogSheetState extends ConsumerState<NewLogSheet> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  LoanType _selectedType = LoanType.lent;
  bool _isLoading = false;
  String? _errorMessage; 
  
  // Tracks if the user picked a dropdown item instead of typing a new name
  Contact? _selectedContact;

  Uint8List? _selectedPhotoBytes;
  Uint8List? _voiceNoteBytes;
  String? _voiceNoteExt;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedPhotoBytes = bytes;
        _errorMessage = null; 
      });
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.audio, 
      );

      if (file != null) {
        // v12+ async length check
        final fileSize = await file.length() ?? 0; 
        
        if (fileSize > 10485760) {
          setState(() {
            _errorMessage = 'Audio is too long! Please select a file under 10MB to save space.';
          });
          return; 
        }

        final bytes = await file.readAsBytes();
        
        setState(() {
          _voiceNoteBytes = bytes;
          _voiceNoteExt = file.name.split('.').last; 
          _errorMessage = null; 
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Audio Pick Error: $e');
    }
  }

  Future<void> _submitLog() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final nameInput = _nameController.text.trim(); 

    if (amount <= 0 || nameInput.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid amount and a contact name.');
      return;
    }

    if (kIsWeb && (_selectedPhotoBytes != null || _voiceNoteBytes != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Testing on Web: Media files skipped.'))
      );
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? existingId;
      String? newName;

      // Smart check: Did they select a contact from the dropdown list?
      if (_selectedContact != null && _selectedContact!.name == nameInput) {
        existingId = _selectedContact!.id; 
      } else {
        newName = nameInput; 
      }

      await ref.read(loanControllerProvider).createLog(
        existingContactId: existingId,
        newContactName: newName,
        amount: amount,
        type: _selectedType,
        receiptPhotoBytes: _selectedPhotoBytes,
        voiceNoteBytes: _voiceNoteBytes,
        voiceNoteExt: _voiceNoteExt,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding, left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Log Transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          SegmentedButton<LoanType>(
            segments: const [
              ButtonSegment(value: LoanType.lent, label: Text('I Lent'), icon: Icon(Icons.arrow_upward)),
              ButtonSegment(value: LoanType.borrowed, label: Text('I Borrowed'), icon: Icon(Icons.arrow_downward)),
            ],
            selected: {_selectedType},
            onSelectionChanged: (newSelection) => setState(() => _selectedType = newSelection.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
          ),
          
          const SizedBox(height: 16),

          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (ETB)', 
              prefixIcon: Icon(Icons.attach_money), 
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // The Smart Dropdown wrapped in a Consumer to access Riverpod streams!
          Consumer(
            builder: (context, ref, child) {
              final contactsAsync = ref.watch(contactsProvider);
              
              return contactsAsync.when(
                data: (contacts) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return DropdownMenu<Contact>(
                        width: constraints.maxWidth, // Fills the container width perfectly
                        controller: _nameController,
                        label: const Text('Contact Name'),
                        leadingIcon: const Icon(Icons.person_outline),
                        enableFilter: true, // Enables typing to search the list
                        requestFocusOnTap: true,
                        dropdownMenuEntries: contacts.map((c) => DropdownMenuEntry(value: c, label: c.name)).toList(),
                        onSelected: (contact) {
                          setState(() => _selectedContact = contact);
                        },
                      );
                    }
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (e, _) => Text('Failed to load contacts: $e', style: const TextStyle(color: Colors.red)),
              );
            },
          ),

          const SizedBox(height: 16),
          
          const Text('Evidence (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          
          Row(
            children: [
              ActionChip(
                label: Text(_selectedPhotoBytes != null ? 'Photo Added' : 'Add Photo'),
                avatar: Icon(Icons.camera_alt_outlined, size: 16, color: _selectedPhotoBytes != null ? Colors.green : null),
                onPressed: _pickPhoto,
              ),
              const SizedBox(width: 12),
              ActionChip(
                label: Text(_voiceNoteBytes != null ? 'Audio Attached' : 'Attach Call File'),
                avatar: Icon(Icons.audio_file_outlined, size: 16, color: _voiceNoteBytes != null ? Colors.green : null),
                onPressed: _pickAudioFile,
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _submitLog,
              child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Save Log', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}