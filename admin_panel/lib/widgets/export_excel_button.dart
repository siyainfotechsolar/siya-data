import 'package:flutter/material.dart';
import '../services/excel_export_service.dart';
import '../services/export_permission_service.dart';

class ExportExcelButton<T> extends StatefulWidget {
  final String filePrefix;
  final String sheetName;
  final List<ExcelColumnDef<T>> columns;
  final Future<List<T>> Function() onFetchFullDataset;
  final Future<List<T>> Function()? onFetchAllDataset;
  final String? reportTitle;
  final String? filterSummary;
  final String label;
  final IconData icon;
  final bool isOutlined;

  const ExportExcelButton({
    super.key,
    required this.filePrefix,
    required this.sheetName,
    required this.columns,
    required this.onFetchFullDataset,
    this.onFetchAllDataset,
    this.reportTitle,
    this.filterSummary,
    this.label = 'Export Excel',
    this.icon = Icons.file_download_outlined,
    this.isOutlined = true,
  });

  @override
  State<ExportExcelButton<T>> createState() => _ExportExcelButtonState<T>();
}

class _ExportExcelButtonState<T> extends State<ExportExcelButton<T>> {
  bool _isExporting = false;

  Future<void> _handleExport() async {
    // 1. Permission check
    final allowed = await ExportPermissionService.canCurrentUserExport();
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to export data. Please contact an Admin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // 2. Fetch full filtered dataset (not just the current page)
      final items = await widget.onFetchFullDataset();

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No records found to export under current filters.'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        return;
      }

      // 3. Generate & trigger file save dialog
      final saved = await ExcelExportService.exportAndSave<T>(
        filePrefix: widget.filePrefix,
        sheetName: widget.sheetName,
        columns: widget.columns,
        items: items,
        reportTitle: widget.reportTitle,
        filterSummary: widget.filterSummary,
      );

      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${items.length} records successfully exported to Excel (.xlsx)!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isExporting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Generating Excel...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (widget.isOutlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F766E),
          side: const BorderSide(color: Color(0xFF14B8A6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        icon: Icon(widget.icon, size: 18),
        label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _handleExport,
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0F766E),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Icon(widget.icon, size: 18),
      label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: _handleExport,
    );
  }
}
