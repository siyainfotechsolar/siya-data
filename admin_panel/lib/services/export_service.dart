import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/consumer_record.dart';
import '../models/report_filter_options.dart';
import '../services/report_service.dart';

class ExportService {
  /// Generate Excel (.xlsx) bytes for filtered records and visible columns
  static List<int> generateExcel({
    required List<ConsumerRecord> records,
    required List<String> visibleColumns,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Siya Reports'];
    excel.setDefaultSheet('Siya Reports');

    // Header Row
    sheet.appendRow(visibleColumns.map((c) => TextCellValue(c)).toList());

    // Data Rows
    for (final r in records) {
      final rowValues = visibleColumns.map((col) {
        return TextCellValue(getColumnValue(r, col));
      }).toList();
      sheet.appendRow(rowValues);
    }

    return excel.save() ?? [];
  }

  /// Generate CSV (.csv) string for filtered records and visible columns
  static String generateCsv({
    required List<ConsumerRecord> records,
    required List<String> visibleColumns,
  }) {
    final List<List<dynamic>> rows = [];

    // Header Row
    rows.add(visibleColumns);

    // Data Rows
    for (final r in records) {
      final row = visibleColumns.map((col) => getColumnValue(r, col)).toList();
      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate PDF bytes for executive report with header, summary cards, and record table
  static Future<Uint8List> generatePdf({
    required List<ConsumerRecord> records,
    required ReportSummaryMetrics summary,
    required WorkflowSummaryMetrics workflow,
    required ReportFilterOptions filters,
    required List<String> visibleColumns,
  }) async {
    final pdf = pw.Document();

    final nowStr = DateTime.now().toLocal().toString().split('.')[0];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Title Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Siya Solar Data - Executive Report',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Official 6-Stage Solar Customer Workflow Analytics',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated: $nowStr', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Total Records: ${records.length}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, height: 16),

            // Applied Filters Summary Box
            if (filters.hasActiveFilters) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Applied Filters: ${_getAppliedFiltersString(filters)}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 12),
            ],

            // Executive Summary Boxes
            pw.Row(
              children: [
                _pdfMetricBox('Total Applications', '${summary.totalApplications}', PdfColors.blue800),
                pw.SizedBox(width: 8),
                _pdfMetricBox('Active Applications', '${summary.activeApplications}', PdfColors.indigo800),
                pw.SizedBox(width: 8),
                _pdfMetricBox('Critical (31+ Days)', '${summary.critical}', PdfColors.red800),
                pw.SizedBox(width: 8),
                _pdfMetricBox('High (16-30 Days)', '${summary.high}', PdfColors.orange800),
                pw.SizedBox(width: 8),
                _pdfMetricBox('Medium (8-15 Days)', '${summary.medium}', PdfColors.amber800),
                pw.SizedBox(width: 8),
                _pdfMetricBox('Normal (0-7 Days)', '${summary.normal}', PdfColors.green800),
                pw.SizedBox(width: 8),
                _pdfMetricBox('Completed', '${summary.completed}', PdfColors.teal800),
              ],
            ),
            pw.SizedBox(height: 14),

            // Workflow Summary Bar
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text('App: ${workflow.application}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Agreement: ${workflow.agreement}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Loan: ${workflow.loan}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Install: ${workflow.installation}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('RTS: ${workflow.rts}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Subsidy: ${workflow.subsidy}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Completed: ${workflow.completed}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Records Table
            pw.TableHelper.fromTextArray(
              headers: visibleColumns,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellPadding: const pw.EdgeInsets.all(4),
              data: records.map((r) {
                return visibleColumns.map((col) => getColumnValue(r, col)).toList();
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfMetricBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: color.shade(0.9),
          border: pw.Border.all(color: color),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.black), textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
  }

  static String _getAppliedFiltersString(ReportFilterOptions f) {
    final List<String> parts = [];
    if (f.workStage != null && f.workStage!.isNotEmpty) parts.add('Stage: ${f.workStage}');
    if (f.status != null && f.status!.isNotEmpty) parts.add('Status: ${f.status}');
    if (f.priority != null && f.priority!.isNotEmpty) parts.add('Priority: ${f.priority}');
    if (f.loanStatus != null && f.loanStatus!.isNotEmpty) parts.add('Loan: ${f.loanStatus}');
    if (f.installationStatus != null && f.installationStatus!.isNotEmpty) parts.add('Install: ${f.installationStatus}');
    if (f.rtsStatus != null && f.rtsStatus!.isNotEmpty) parts.add('RTS: ${f.rtsStatus}');
    if (f.subsidyStatus != null && f.subsidyStatus!.isNotEmpty) parts.add('Subsidy: ${f.subsidyStatus}');
    if (f.searchQuery.isNotEmpty) parts.add('Search: "${f.searchQuery}"');
    return parts.isEmpty ? 'None' : parts.join(' | ');
  }

  static String getColumnValue(ConsumerRecord r, String col) {
    switch (col) {
      case 'Customer Name':
        return r.name;
      case 'Consumer No':
        return r.consumerNo;
      case 'Application ID':
        return r.applicationId ?? '-';
      case 'Application Date':
        return r.applicationDate != null ? r.applicationDate!.toIso8601String().split('T')[0] : '-';
      case 'Submit Date':
        return r.submitDate != null ? r.submitDate!.toIso8601String().split('T')[0] : '-';
      case 'Application Days':
        return '${r.applicationDays} Days';
      case 'Priority':
        return r.priority;
      case 'Current Work Stage':
        return r.overallStage;
      case 'Current Status':
        return r.status;
      case 'Application Status':
        return r.applicationStatus;
      case 'Agreement Status':
        return r.agreementStatus;
      case 'Loan Required':
        return r.loanRequired;
      case 'Loan Status':
        return r.loanStatus;
      case 'Installation Status':
        return r.installationStatus;
      case 'RTS Status':
        return r.rtsStatus;
      case 'Subsidy Status':
        return r.subsidyStatus;
      case 'Assigned Staff':
        return r.createdBy ?? r.updatedBy ?? '-';
      default:
        return '-';
    }
  }
}
