import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/msedcl_change_of_name.dart';
import '../utils/universal_file_saver.dart';

class MsedclExcelService {
  static final DateFormat _dateFormatter = DateFormat('dd-MM-yyyy');

  /// Builds a 5-sheet Excel workbook containing:
  /// - Sheet 1: All Applications
  /// - Sheet 2: Pending Applications
  /// - Sheet 3: Completed / Approved Applications
  /// - Sheet 4: Sub-Division Breakdown
  /// - Sheet 5: Employee Breakdown
  static Excel generateWorkbook({
    required List<MsedclChangeOfNameApplication> applications,
    String? appliedFilterDescription,
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    final now = DateTime.now();
    final generatedDateStr = DateFormat('dd-MM-yyyy HH:mm').format(now);
    final effectiveFilters = appliedFilterDescription ?? 'All Records (Unfiltered)';

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#0F3B7A'),
    );

    final metaStyle = CellStyle(
      fontSize: 10,
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#4B5563'),
    );

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0F3B7A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final totalCount = applications.length;
    final pendingList = applications.where((a) => a.status != MsedclApplicationStatus.approved && a.status != MsedclApplicationStatus.nameChanged).toList();
    final completedList = applications.where((a) => a.status == MsedclApplicationStatus.approved || a.status == MsedclApplicationStatus.nameChanged).toList();

    // -------------------------------------------------------------------------
    // SHEET 1: ALL APPLICATIONS
    // -------------------------------------------------------------------------
    final sheet1 = excel['All Applications'];
    _addTitleAndMeta(
      sheet: sheet1,
      title: 'MSEDCL CHANGE OF NAME — ALL APPLICATIONS',
      meta: 'Generated on: $generatedDateStr | Total: $totalCount records | Filter: $effectiveFilters',
      titleStyle: titleStyle,
      metaStyle: metaStyle,
    );

    final headers1 = [
      'Sr. No.',
      'Application No.',
      'Application Date',
      'Consumer No.',
      'Old Consumer Name',
      'New Consumer Name',
      'Mobile Number',
      'Sub-Division Office',
      'Village / Location',
      'Reason for Name Change',
      'Status',
      'Docs Received',
      'Assigned Staff',
      'Remarks',
    ];
    _addHeaderRow(sheet1, headers1, headerStyle);

    for (int i = 0; i < applications.length; i++) {
      final a = applications[i];
      sheet1.appendRow([
        IntCellValue(i + 1),
        TextCellValue(a.applicationNo),
        TextCellValue(_dateFormatter.format(a.applicationDate)),
        TextCellValue(a.consumerNo),
        TextCellValue(a.computedOldFullName),
        TextCellValue(a.computedNewFullName),
        TextCellValue(a.newMobileNo),
        TextCellValue(a.subDivisionOffice),
        TextCellValue(a.village),
        TextCellValue(a.reasonForChange),
        TextCellValue(a.status),
        TextCellValue('${a.receivedDocCount} / ${a.applicableDocCount}'),
        TextCellValue(a.assignedEmployee),
        TextCellValue(a.remarks),
      ]);
    }

    // -------------------------------------------------------------------------
    // SHEET 2: PENDING APPLICATIONS
    // -------------------------------------------------------------------------
    final sheet2 = excel['Pending Applications'];
    _addTitleAndMeta(
      sheet: sheet2,
      title: 'MSEDCL CHANGE OF NAME — PENDING APPLICATIONS',
      meta: 'Generated on: $generatedDateStr | Pending: ${pendingList.length} applications',
      titleStyle: titleStyle,
      metaStyle: metaStyle,
    );

    _addHeaderRow(sheet2, headers1, headerStyle);

    for (int i = 0; i < pendingList.length; i++) {
      final a = pendingList[i];
      sheet2.appendRow([
        IntCellValue(i + 1),
        TextCellValue(a.applicationNo),
        TextCellValue(_dateFormatter.format(a.applicationDate)),
        TextCellValue(a.consumerNo),
        TextCellValue(a.computedOldFullName),
        TextCellValue(a.computedNewFullName),
        TextCellValue(a.newMobileNo),
        TextCellValue(a.subDivisionOffice),
        TextCellValue(a.village),
        TextCellValue(a.reasonForChange),
        TextCellValue(a.status),
        TextCellValue('${a.receivedDocCount} / ${a.applicableDocCount}'),
        TextCellValue(a.assignedEmployee),
        TextCellValue(a.remarks),
      ]);
    }

    // -------------------------------------------------------------------------
    // SHEET 3: COMPLETED / APPROVED APPLICATIONS
    // -------------------------------------------------------------------------
    final sheet3 = excel['Completed Applications'];
    _addTitleAndMeta(
      sheet: sheet3,
      title: 'MSEDCL CHANGE OF NAME — COMPLETED & APPROVED APPLICATIONS',
      meta: 'Generated on: $generatedDateStr | Completed: ${completedList.length} applications',
      titleStyle: titleStyle,
      metaStyle: metaStyle,
    );

    _addHeaderRow(sheet3, headers1, headerStyle);

    for (int i = 0; i < completedList.length; i++) {
      final a = completedList[i];
      sheet3.appendRow([
        IntCellValue(i + 1),
        TextCellValue(a.applicationNo),
        TextCellValue(_dateFormatter.format(a.applicationDate)),
        TextCellValue(a.consumerNo),
        TextCellValue(a.computedOldFullName),
        TextCellValue(a.computedNewFullName),
        TextCellValue(a.newMobileNo),
        TextCellValue(a.subDivisionOffice),
        TextCellValue(a.village),
        TextCellValue(a.reasonForChange),
        TextCellValue(a.status),
        TextCellValue('${a.receivedDocCount} / ${a.applicableDocCount}'),
        TextCellValue(a.assignedEmployee),
        TextCellValue(a.remarks),
      ]);
    }

    // -------------------------------------------------------------------------
    // SHEET 4: SUB-DIVISION BREAKDOWN
    // -------------------------------------------------------------------------
    final sheet4 = excel['Sub-Division Breakdown'];
    _addTitleAndMeta(
      sheet: sheet4,
      title: 'MSEDCL CHANGE OF NAME — SUB-DIVISION BREAKDOWN',
      meta: 'Generated on: $generatedDateStr',
      titleStyle: titleStyle,
      metaStyle: metaStyle,
    );

    final subHeaders = ['Sr.', 'Sub-Division Office', 'Total Apps', 'Pending', 'Approved / Changed'];
    _addHeaderRow(sheet4, subHeaders, headerStyle);

    final Map<String, List<MsedclChangeOfNameApplication>> subDivisionMap = {};
    for (final a in applications) {
      subDivisionMap.putIfAbsent(a.subDivisionOffice, () => []).add(a);
    }

    int sIdx = 1;
    for (final entry in subDivisionMap.entries) {
      final list = entry.value;
      final pending = list.where((a) => a.status != MsedclApplicationStatus.approved && a.status != MsedclApplicationStatus.nameChanged).length;
      final done = list.length - pending;

      sheet4.appendRow([
        IntCellValue(sIdx++),
        TextCellValue(entry.key),
        IntCellValue(list.length),
        IntCellValue(pending),
        IntCellValue(done),
      ]);
    }

    // -------------------------------------------------------------------------
    // SHEET 5: EMPLOYEE BREAKDOWN
    // -------------------------------------------------------------------------
    final sheet5 = excel['Employee Breakdown'];
    _addTitleAndMeta(
      sheet: sheet5,
      title: 'MSEDCL CHANGE OF NAME — EMPLOYEE / STAFF BREAKDOWN',
      meta: 'Generated on: $generatedDateStr',
      titleStyle: titleStyle,
      metaStyle: metaStyle,
    );

    final empHeaders = ['Sr.', 'Assigned Staff', 'Assigned Apps', 'Pending', 'Completed'];
    _addHeaderRow(sheet5, empHeaders, headerStyle);

    final Map<String, List<MsedclChangeOfNameApplication>> empMap = {};
    for (final a in applications) {
      empMap.putIfAbsent(a.assignedEmployee, () => []).add(a);
    }

    int eIdx = 1;
    for (final entry in empMap.entries) {
      final list = entry.value;
      final pending = list.where((a) => a.status != MsedclApplicationStatus.approved && a.status != MsedclApplicationStatus.nameChanged).length;
      final done = list.length - pending;

      sheet5.appendRow([
        IntCellValue(eIdx++),
        TextCellValue(entry.key.isNotEmpty ? entry.key : 'Unassigned'),
        IntCellValue(list.length),
        IntCellValue(pending),
        IntCellValue(done),
      ]);
    }

    if (defaultSheet != 'All Applications' && excel.tables.containsKey(defaultSheet)) {
      excel.delete(defaultSheet);
    }

    return excel;
  }

  /// Exports and saves the workbook using UniversalFileSaver
  static Future<String?> exportAndSave({
    required List<MsedclChangeOfNameApplication> applications,
    String? appliedFilterDescription,
  }) async {
    final excel = generateWorkbook(
      applications: applications,
      appliedFilterDescription: appliedFilterDescription,
    );

    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    final bytes = Uint8List.fromList(fileBytes);
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final defaultFileName = 'MSEDCL_Name_Change_Report_$dateStr.xlsx';

    return await saveFileUniversal(
      bytes: bytes,
      fileName: defaultFileName,
      dialogTitle: 'Export MSEDCL Change of Name Report',
    );
  }

  static void _addTitleAndMeta({
    required Sheet sheet,
    required String title,
    required String meta,
    required CellStyle titleStyle,
    required CellStyle metaStyle,
  }) {
    sheet.appendRow([TextCellValue(title)]);
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1));
    titleCell.cellStyle = titleStyle;

    sheet.appendRow([TextCellValue(meta)]);
    final metaCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sheet.maxRows - 1));
    metaCell.cellStyle = metaStyle;

    sheet.appendRow([]); // empty spacer row
  }

  static void _addHeaderRow(Sheet sheet, List<String> headers, CellStyle headerStyle) {
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    final rowIndex = sheet.maxRows - 1;
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.cellStyle = headerStyle;
    }
  }
}
