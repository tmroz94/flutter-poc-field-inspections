import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/inspection.dart';
import '../../l10n/l10n.dart';

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
    '„': '"',
    '”': '"',
    '“': '"',
  };
  return s.split('').map((c) => map[c] ?? c).join();
}

/// Inspection report: summary, people, checklist results and history, in the
/// app's language ([l], [locale]; English by default). Pure Dart, so it
/// renders the same on iOS, Android and the web.
Future<Uint8List> buildInspectionReport(
  InspectionDetail d,
  List<ChecklistItem> checklist, {
  DateTime? now,
  AppLocalizations? l,
  String? locale,
}) async {
  final t = l ?? lookupAppLocalizations(const Locale('en'));
  final s = d.summary;
  final date = _dateFormat(locale);
  final doc = pw.Document(title: _ascii(t.inspectionNamed(s.id)), author: 'Field Inspections PoC');
  final failed = checklist.where((i) => d.answers[i.id] == Answer.fail).length;

  pw.Widget row(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(_ascii(k), style: const pw.TextStyle(color: PdfColors.grey700)),
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
            _ascii(t.appName),
            style: const pw.TextStyle(color: PdfColor.fromInt(0xFF6750A4), fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(s.id, style: const pw.TextStyle(color: PdfColors.grey700)),
        ],
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          _ascii(t.pdfFooter(c.pageNumber, c.pagesCount, date.format(now ?? DateTime.now()))),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (c) => [
        pw.SizedBox(height: 12),
        pw.Text(_ascii(s.site), style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          _ascii('${s.status.localized(t)} | ${date.format(s.scheduledAt)} | ${d.durationMin} min'),
          style: const pw.TextStyle(color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        row(t.pdfAddress, '${s.address}, ${d.postcode} ${s.city}'),
        row(t.pdfType, s.type),
        row(t.priority, switch (s.priority) {
          Priority.low => t.priorityLow,
          Priority.normal => t.priorityNormal,
          Priority.high => t.priorityHigh,
        }),
        row(t.pdfSiteManager, '${d.siteManager.name} ${d.siteManager.phone ?? ''}'),
        row(t.pdfInspector, d.inspector.name),
        if (d.notes.isNotEmpty) row(t.notes, d.notes),
        pw.SizedBox(height: 16),
        pw.Text(
          _ascii(t.pdfChecklistSummary(d.answers.length, checklist.length, failed)),
          style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: [_ascii(t.pdfItem), _ascii(t.pdfResult)],
          data: [
            for (final i in checklist)
              [
                _ascii(i.title),
                _ascii(switch (d.answers[i.id]) {
                  Answer.pass => t.answerPass,
                  Answer.fail => t.answerFail.toUpperCase(),
                  Answer.na => t.answerNa,
                  null => '-',
                }),
              ],
          ],
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignments: {1: pw.Alignment.centerRight},
        ),
        if (d.history.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(_ascii(t.tabHistory), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final h in d.history) row(date.format(h.at), [h.title, ?h.by].join(' | ')),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Day-month dates in the app's language; intl's default when that
/// language's data isn't loaded (tests without the app's localizations).
DateFormat _dateFormat(String? locale) {
  const pattern = 'd MMM y, HH:mm';
  if (locale == null) return DateFormat(pattern);
  try {
    return DateFormat(pattern, locale.replaceAll('-', '_'));
  } on Object {
    return DateFormat(pattern);
  }
}
