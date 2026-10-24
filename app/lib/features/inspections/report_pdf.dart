import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/inspection.dart';

/// The PDF's built-in Helvetica has no Polish letters. Bundling a Unicode
/// font is the production fix (docs/decisions.md); the PoC transliterates.
String _ascii(String s) {
  const map = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
    'Ą': 'A',
    'Ć': 'C',
    'Ę': 'E',
    'Ł': 'L',
    'Ń': 'N',
    'Ó': 'O',
    'Ś': 'S',
    'Ź': 'Z',
    'Ż': 'Z',
    '–': '-',
    '−': '-',
    '·': '|',
  };
  return s.split('').map((c) => map[c] ?? c).join();
}

/// Inspection report: summary, people, checklist results and history.
/// Pure Dart, so it renders the same on iOS, Android and the web.
Future<Uint8List> buildInspectionReport(InspectionDetail d, List<ChecklistItem> checklist, {DateTime? now}) async {
  final s = d.summary;
  final date = DateFormat('d MMM y, HH:mm');
  final doc = pw.Document(title: 'Inspection ${s.id}', author: 'Field Inspections PoC');
  final failed = checklist.where((i) => d.answers[i.id] == Answer.fail).length;

  pw.Widget row(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(k, style: const pw.TextStyle(color: PdfColors.grey700)),
        ),
        pw.Expanded(child: pw.Text(_ascii(v))),
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Field Inspections',
            style: const pw.TextStyle(color: PdfColor.fromInt(0xFF6750A4), fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(s.id, style: const pw.TextStyle(color: PdfColors.grey700)),
        ],
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${c.pageNumber} of ${c.pagesCount} | generated ${date.format(now ?? DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (c) => [
        pw.SizedBox(height: 12),
        pw.Text(_ascii(s.site), style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          '${s.status.label} | ${date.format(s.scheduledAt)} | ${d.durationMin} min',
          style: const pw.TextStyle(color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        row('Address', '${s.address}, ${d.postcode} ${s.city}'),
        row('Type', s.type),
        row('Priority', s.priority.name),
        row('Site manager', '${d.siteManager.name} ${d.siteManager.phone ?? ''}'),
        row('Inspector', d.inspector.name),
        if (d.notes.isNotEmpty) row('Notes', d.notes),
        pw.SizedBox(height: 16),
        pw.Text(
          'Checklist: ${d.answers.length} of ${checklist.length} answered, $failed failed',
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Result'],
          data: [
            for (final i in checklist)
              [
                _ascii(i.title),
                switch (d.answers[i.id]) {
                  Answer.pass => 'Pass',
                  Answer.fail => 'FAIL',
                  Answer.na => 'N/A',
                  null => '-',
                },
              ],
          ],
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignments: {1: pw.Alignment.centerRight},
        ),
        if (d.history.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('History', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final h in d.history) row(date.format(h.at), [h.title, ?h.by].join(' | ')),
        ],
      ],
    ),
  );
  return doc.save();
}
