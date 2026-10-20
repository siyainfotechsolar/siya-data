import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class SaveDocToCustomerDialog extends StatefulWidget {
  final Uint8List pdfBytes;
  final String defaultDocName;

  const SaveDocToCustomerDialog({
    super.key,
    required this.pdfBytes,
    required this.defaultDocName,
  });

  @override
  State<SaveDocToCustomerDialog> createState() => _SaveDocToCustomerDialogState();
}

class _SaveDocToCustomerDialogState extends State<SaveDocToCustomerDialog> {
  final _searchController = TextEditingController();
  final _docNameController = TextEditingController();
  String _selectedDocType = 'Identity Proof';

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedCustomer;
  bool _isSearching = false;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _docTypes = [
    'Identity Proof',
    'Aadhaar Card',
    'Electricity Bill',
    'Site Photograph',
    'Bank Passbook / Cheque',
    'Quotation / Agreement',
    'General Document',
  ];

  @override
  void initState() {
    super.initState();
    _docNameController.text = widget.defaultDocName;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _docNameController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomer(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final client = SupabaseService.client;
      final res = await client
          .from('consumer_records')
          .select('id, name, consumer_no, mobile, address, village_city')
          .or('name.ilike.%$q%,consumer_no.ilike.%$q%,mobile.ilike.%$q%')
          .limit(8);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(res);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to search customer: $e';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _saveToCustomer() async {
    if (_selectedCustomer == null) {
      setState(() => _errorMessage = 'Please select a customer first.');
      return;
    }

    final docTitle = _docNameController.text.trim();
    if (docTitle.isEmpty) {
      setState(() => _errorMessage = 'Please enter a document title.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final client = SupabaseService.client;
      final customerId = _selectedCustomer!['id'].toString();
      final consumerNo = (_selectedCustomer!['consumer_no'] ?? '').toString();
      final userId = SupabaseService.currentUser?.id;

      final sanitizedName = docTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$sanitizedName.pdf';
      final storagePath = 'customer_docs/$customerId/$fileName';

      // 1. Upload to Supabase Storage
      await client.storage.from('customer-documents').uploadBinary(
            storagePath,
            widget.pdfBytes,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );

      final publicUrl = client.storage.from('customer-documents').getPublicUrl(storagePath);

      // 2. Insert into customer_documents table
      await client.from('customer_documents').insert({
        'customer_id': customerId,
        'consumer_no': consumerNo,
        'document_type': _selectedDocType,
        'document_name': '$docTitle.pdf',
        'file_url': publicUrl,
        'source': 'Document Clear & A4 Print Tool',
        'uploaded_by': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save document: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.folder_shared_outlined, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Save to Customer Record',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Attach processed A4 document directly to an existing customer record',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Customer Selection
              if (_selectedCustomer == null) ...[
                const Text('Search Customer:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter name, consumer number, or mobile...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (_searchController.text == val) {
                        _searchCustomer(val);
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.trim().isEmpty
                                ? 'Type a customer name or consumer number above.'
                                : 'No matching customers found.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = _searchResults[i];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                child: Text(
                                  (c['name'] as String? ?? 'C').characters.first.toUpperCase(),
                                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(c['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Consumer: ${c['consumer_no'] ?? '-'} | Mobile: ${c['mobile'] ?? '-'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: ElevatedButton.icon(
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Select', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  setState(() => _selectedCustomer = c);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ] else ...[
                // Selected Customer Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCustomer!['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Consumer No: ${_selectedCustomer!['consumer_no'] ?? '-'} | Phone: ${_selectedCustomer!['mobile'] ?? '-'}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.change_circle_outlined, size: 16),
                        label: const Text('Change'),
                        onPressed: () => setState(() => _selectedCustomer = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Document Type:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDocType,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: _docTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDocType = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Document Title:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _docNameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Aadhaar Card Cleaned',
                    isDense: true,
                  ),
                ),
                const Spacer(),
              ],

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save to Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: (_isSaving || _selectedCustomer == null) ? null : _saveToCustomer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
