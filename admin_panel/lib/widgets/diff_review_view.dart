import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/record_diff.dart';

class DiffReviewView extends StatefulWidget {
  final DuplicateAnalysisResult analysis;
  final ConflictStrategy selectedStrategy;
  final ValueChanged<ConflictStrategy> onStrategyChanged;
  final VoidCallback onDataChanged;

  const DiffReviewView({
    super.key,
    required this.analysis,
    required this.selectedStrategy,
    required this.onStrategyChanged,
    required this.onDataChanged,
  });

  @override
  State<DiffReviewView> createState() => _DiffReviewViewState();
}

class _DiffReviewViewState extends State<DiffReviewView> {
  @override
  Widget build(BuildContext context) {
    final conflicts = widget.analysis.conflictRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Overview Banner
        _buildOverviewBadges(),
        const SizedBox(height: 12),

        // Policy Notice Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only columns selected for UPDATE will be overwritten. SKIPPED fields are strictly preserved.',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Strategy Selector Card
        _buildStrategySelector(),
        const SizedBox(height: 16),

        // Conflicts List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Modified Records Comparison (${conflicts.length})',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            if (conflicts.isNotEmpty)
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final c in conflicts) {
                          c.shouldUpdate = true;
                        }
                      });
                      widget.onDataChanged();
                    },
                    child: const Text('Select All'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final c in conflicts) {
                          c.shouldUpdate = false;
                        }
                      });
                      widget.onDataChanged();
                    },
                    child: const Text('Deselect All'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Conflicts List
        Expanded(
          child: conflicts.isEmpty
              ? _buildNoConflictsPlaceholder()
              : ListView.builder(
                  itemCount: conflicts.length,
                  itemBuilder: (context, index) {
                    final diff = conflicts[index];
                    return _buildDiffCard(diff);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOverviewBadges() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildBadge(
            'New Consumers',
            widget.analysis.newRecords.length.toString(),
            const Color(0xFF0F766E),
            const Color(0xFFCCFBF1),
            Icons.person_add_outlined,
          ),
          const SizedBox(width: 12),
          _buildBadge(
            'Identical (No Changes)',
            widget.analysis.identicalRecords.length.toString(),
            const Color(0xFF64748B),
            Colors.grey.shade200,
            Icons.check_circle_outline,
          ),
          const SizedBox(width: 12),
          _buildBadge(
            'Modified / Conflicting',
            widget.analysis.conflictRecords.length.toString(),
            const Color(0xFFD97706),
            const Color(0xFFFEF3C7),
            Icons.compare_arrows_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, String count, Color textColor, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: textColor)),
          Text(count, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildStrategySelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Strategy for Existing Records:',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStrategyRadio(
                ConflictStrategy.updateNonEmptyOnly,
                'Smart Update (Non-Empty Only)',
                'Only overwrite fields if new Excel cell is not blank (Recommended)',
              ),
              _buildStrategyRadio(
                ConflictStrategy.overwriteAll,
                'Overwrite All Fields',
                'Replace all existing fields with incoming file values',
              ),
              _buildStrategyRadio(
                ConflictStrategy.skipExisting,
                'Skip Existing Records',
                'Only insert new consumers, keep all existing records unchanged',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyRadio(ConflictStrategy strategy, String title, String subtitle) {
    final isSelected = widget.selectedStrategy == strategy;

    return InkWell(
      onTap: () => widget.onStrategyChanged(strategy),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706).withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFD97706) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<ConflictStrategy>(
              value: strategy,
              groupValue: widget.selectedStrategy,
              activeColor: const Color(0xFFD97706),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) {
                if (val != null) widget.onStrategyChanged(val);
              },
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffCard(RecordDiff diff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: diff.shouldUpdate ? const Color(0xFFD97706).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: diff.shouldUpdate ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: diff.shouldUpdate,
                  activeColor: const Color(0xFFD97706),
                  onChanged: (val) {
                    setState(() => diff.shouldUpdate = val ?? true);
                    widget.onDataChanged();
                  },
                ),
                Text(
                  'Consumer No: ${diff.existingRecord.consumerNo}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                const SizedBox(width: 12),
                Text(
                  '(${diff.existingRecord.name})',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${diff.changedFields.length} field(s) changed',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),

          // Fields Comparison Table
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: diff.changedFields.map((field) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          field.fieldLabel,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                      ),
                      // Old Value
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            field.oldValue?.isNotEmpty == true ? field.oldValue! : '(empty)',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                      // New Value
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            field.newValue?.isNotEmpty == true ? field.newValue! : '(empty)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF065F46),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConflictsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green.shade400),
          const SizedBox(height: 12),
          Text(
            'No Modified Records Found',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            'All incoming records are brand new or identical to existing data.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
