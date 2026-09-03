import 'package:flutter/material.dart';
import '../models/duplicate_group.dart';
import '../services/duplicate_finder_service.dart';
import '../widgets/smart_merge_dialog.dart';

class DuplicateFinderScreen extends StatefulWidget {
  const DuplicateFinderScreen({super.key});

  @override
  State<DuplicateFinderScreen> createState() => _DuplicateFinderScreenState();
}

class _DuplicateFinderScreenState extends State<DuplicateFinderScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<DuplicateGroup> _groups = [];
  String _selectedMatchTypeFilter = 'ALL';
  String _sortBy = 'count';

  @override
  void initState() {
    super.initState();
    _loadDuplicateGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDuplicateGroups() async {
    setState(() => _isLoading = true);

    try {
      final groups = await DuplicateFinderService.fetchDuplicateGroups(
        searchQuery: _searchController.text,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load Duplicate Groups: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openMergeDialog(DuplicateGroup group) {
    showDialog(
      context: context,
      builder: (_) => SmartMergeDialog(
        group: group,
        onMergeCompleted: _loadDuplicateGroups,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalGroups = _groups.length;
    final totalRecords = _groups.fold<int>(0, (sum, g) => sum + g.recordCount);
    final exactMatches = _groups.where((g) => g.matchType == DuplicateMatchType.exactMatch).length;
    final formattingVariations = _groups.where((g) => g.matchType == DuplicateMatchType.formattingVariation).length;

    final displayedGroups = _groups.where((g) {
      if (_selectedMatchTypeFilter == 'EXACT') return g.matchType == DuplicateMatchType.exactMatch;
      if (_selectedMatchTypeFilter == 'FORMATTING') return g.matchType == DuplicateMatchType.formattingVariation;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.find_in_page_rounded, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Duplicate Finder & Smart Merge',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Detects duplicate records by normalized Consumer No and provides safe field-by-field merge.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Duplicates',
                onPressed: _loadDuplicateGroups,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildSummaryStatCard('Duplicate Groups', '$totalGroups', Icons.folder_special_outlined, Colors.blue),
              _buildSummaryStatCard('Total Duplicate Records', '$totalRecords', Icons.difference_outlined, Colors.orange),
              _buildSummaryStatCard('Exact Matches', '$exactMatches', Icons.library_add_check_outlined, Colors.green),
              _buildSummaryStatCard('Formatting Variations', '$formattingVariations', Icons.text_format_rounded, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Search & Filter Bar Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _loadDuplicateGroups(),
                      decoration: InputDecoration(
                        hintText: 'Search Duplicates by Consumer No, Name, Mobile...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadDuplicateGroups();
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Match Type Filter
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedMatchTypeFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Duplicate Types')),
                          DropdownMenuItem(value: 'EXACT', child: Text('Exact Matches')),
                          DropdownMenuItem(value: 'FORMATTING', child: Text('Formatting Variations')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMatchTypeFilter = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Sort By Dropdown
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _sortBy,
                        items: const [
                          DropdownMenuItem(value: 'count', child: Text('Sort: Record Count')),
                          DropdownMenuItem(value: 'appDays', child: Text('Sort: Application Days')),
                          DropdownMenuItem(value: 'submitDate', child: Text('Sort: Submit Date')),
                          DropdownMenuItem(value: 'name', child: Text('Sort: Customer Name')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _sortBy = val);
                            _loadDuplicateGroups();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Duplicate Groups List
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              : displayedGroups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Text(
                          'No duplicate record groups found.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedGroups.length,
                      itemBuilder: (ctx, i) {
                        final g = displayedGroups[i];
                        return _buildDuplicateGroupCard(g);
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateGroupCard(DuplicateGroup group) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Title Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Consumer No: ${group.normalizedConsumerNo}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: group.matchType == DuplicateMatchType.exactMatch ? Colors.green.shade50 : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: group.matchType == DuplicateMatchType.exactMatch ? Colors.green.shade300 : Colors.purple.shade300),
                      ),
                      child: Text(
                        group.matchType.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: group.matchType == DuplicateMatchType.exactMatch ? Colors.green.shade800 : Colors.purple.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${group.recordCount} Duplicate Records',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.merge_type_rounded, size: 18),
                  label: const Text('Compare & Merge'),
                  onPressed: () => _openMergeDialog(group),
                ),
              ],
            ),
            const Divider(height: 20),

            // Members Table
            Column(
              children: group.records.map((r) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Raw: "${r.consumerNo}"', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Mobile: ${r.mobile ?? "—"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Stage: ${r.overallStage}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text('${r.applicationDays} Days (${r.priority})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
