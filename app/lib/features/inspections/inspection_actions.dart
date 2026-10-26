import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/deep_links.dart';
import '../../core/router/routes.dart';
import '../../data/models/inspection.dart';
import 'inspections_controller.dart';
import 'report_pdf.dart';

/// Directions, call, share and PDF export for an inspection (P06, T04, D03, P16).
class InspectionActions {
  InspectionActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  Capabilities get _caps => ref.read(capabilitiesProvider);

  void _say(String message) {
    // The newest message replaces the last one ("Preparing…" → "Report saved").
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Link to open this inspection: the page URL on the web, the app's custom
  /// scheme on mobile (opens the app on another device that has it).
  Uri link(String path) => _caps.isWeb ? Uri.base.resolve(path) : Uri.parse('${DeepLinks.scheme}://${DeepLinks.schemeHost}$path');

  Future<void> directions(InspectionSummary s) async {
    if (s.lat == null || s.lng == null) return _say('No map location for this site.');
    final ok = await ref.read(launcherServiceProvider).open(ref.read(launcherServiceProvider).directionsUri(s.lat!, s.lng!, caps: _caps));
    if (!ok) _say("Couldn't open maps.");
  }

  Future<void> call(Person p) async {
    final phone = p.phone;
    if (phone == null) return _say('No phone number for ${p.name}.');
    final ok = await ref.read(launcherServiceProvider).open(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    // Desktop browsers without a phone app can't handle tel: links.
    if (!ok) _say('Call ${p.name}: $phone');
  }

  Future<void> share(InspectionSummary s, {String? path}) async {
    final outcome = await ref
        .read(shareServiceProvider)
        .shareLink(text: '${s.site} (${s.id})', subject: 'Inspection ${s.id}', link: link(path ?? Routes.inspection(s.id)));
    if (outcome == ShareOutcome.copied) _say('Sharing is not available here; link copied instead.');
  }

  Future<void> exportPdf(InspectionDetail d) async {
    _say('Preparing the PDF report…');
    final checklist = await ref.read(checklistProvider(d.templateId).future);
    final bytes = await buildInspectionReport(d, checklist);
    final outcome = await ref
        .read(shareServiceProvider)
        .shareFile(bytes: bytes, fileName: 'inspection-${d.id}.pdf', mime: 'application/pdf', caps: _caps);
    if (_caps.isWeb && outcome == ShareOutcome.shared) _say('Report downloaded: inspection-${d.id}.pdf');
    if (outcome == ShareOutcome.saved) _say('Report saved: inspection-${d.id}.pdf');
  }
}
