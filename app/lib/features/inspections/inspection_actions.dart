import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../core/platform/platform_services.dart';
import '../../core/router/deep_links.dart';
import '../../core/router/routes.dart';
import '../../data/models/inspection.dart';
import '../../l10n/l10n.dart';
import 'inspections_controller.dart';
import 'report_pdf.dart';

/// Link to an in-app [path]: the page URL on the web, the app's custom scheme
/// on mobile (opens the app on another device that has it).
Uri appLink(Capabilities caps, String path) =>
    caps.isWeb ? Uri.base.resolve(path) : Uri.parse('${DeepLinks.scheme}://${DeepLinks.schemeHost}$path');

/// Directions, call, share, copy link and PDF export for an inspection (P06, T04, D03, P16).
class InspectionActions {
  InspectionActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  Capabilities get _caps => ref.read(capabilitiesProvider);

  void _say(String message) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Uri link(String path) => appLink(_caps, path);

  Future<void> copyLink(String path) async {
    final l = context.l10n;
    final text = link(path).toString();
    await Clipboard.setData(ClipboardData(text: text));
    _say(l.linkCopied(text));
  }

  Future<void> directions(InspectionSummary s) async {
    final l = context.l10n;
    if (s.lat == null || s.lng == null) return _say(l.noMapLocation);
    final launcher = ref.read(launcherServiceProvider);
    final ok = await launcher.open(launcher.directionsUri(s.lat!, s.lng!, caps: _caps));
    if (!ok) _say(l.mapsOpenFailed);
  }

  Future<void> call(Person p) async {
    final l = context.l10n;
    final phone = p.phone;
    if (phone == null) return _say(l.noPhoneFor(p.name));
    final ok = await ref.read(launcherServiceProvider).open(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    // Desktop browsers without a phone app can't handle tel: links.
    if (!ok) _say(l.callPerson(p.name, phone));
  }

  /// Shares the inspection (or [paths] inside it, e.g. selected photos), one link per line.
  Future<void> share(InspectionSummary s, {List<String>? paths}) async {
    final l = context.l10n;
    final links = [
      for (final p in paths ?? [Routes.inspection(s.id)]) link(p),
    ];
    final text = ['${s.site} (${s.id})', ...links.take(links.length - 1)].join('\n');
    final outcome = await ref.read(shareServiceProvider).shareLink(text: text, subject: l.inspectionNamed(s.id), link: links.last);
    if (outcome == ShareOutcome.copied) _say(l.sharingUnavailable);
  }

  /// Builds the report in the app's language and shares or downloads it.
  /// Failures (offline checklist, share sheet errors) show a message.
  Future<void> exportPdf(InspectionDetail d) async {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    _say(l.preparingPdf);
    try {
      final checklist = await ref.read(checklistProvider(d.templateId).future);
      final bytes = await buildInspectionReport(d, checklist, l: l, locale: locale);
      final outcome = await ref
          .read(shareServiceProvider)
          .shareFile(bytes: bytes, fileName: 'inspection-${d.id}.pdf', mime: 'application/pdf', isWeb: _caps.isWeb);
      if (_caps.isWeb && outcome == ShareOutcome.shared) _say(l.pdfDownloaded('inspection-${d.id}.pdf'));
    } on Object catch (e) {
      debugPrint('PDF export failed: $e');
      _say(l.pdfFailed);
    }
  }
}
