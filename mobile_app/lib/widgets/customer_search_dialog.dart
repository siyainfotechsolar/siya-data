import 'dart:async';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/task_service.dart';

class CustomerSearchDialog extends StatefulWidget {
  final String? initialQuery;

  const CustomerSearchDialog({super.key, this.initialQuery});

  @override
  State<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  late final TextEditingController _searchController;
  List<ConsumerRecord> _results = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    final results = await TaskService.searchCustomers(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSearchQuery = _searchController.text.isNotEmpty;

    return PopScope(
      canPop: !hasSearchQuery,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _searchController.clear();
          _results = [];
        });
      },
      child: Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_search_rounded,
                    color: Color(0xFF059669)),
                const SizedBox(width: 8),
                const Text(
                  'Select Customer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search Name, Consumer No, Mobile, Village...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const LinearProgressIndicator()
            else if (_results.isEmpty &&
                _searchController.text.trim().isNotEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No customers found matching "${_searchController.text}".',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else if (_results.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Type to search by name, consumer number, mobile or village.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final c = _results[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      title: Text(
                        c.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text('Cons No: ${c.consumerNo}',
                                  style: const TextStyle(fontSize: 12)),
                              if (c.mobile != null && c.mobile!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text('• ${c.mobile}',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ],
                          ),
                          if (c.address != null && c.address!.isNotEmpty)
                            Text(
                              c.address!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.of(context).pop(c);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
