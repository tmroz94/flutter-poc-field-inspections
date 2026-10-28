import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../inspections/inspection_actions.dart';

/// P16: shown after submit. Sent → "Report submitted"; offline → "saved and
/// queued". The badge pops and the text rises (explicit animation), unless
/// the OS or the app asks for reduced motion.
class SubmittedScreen extends ConsumerStatefulWidget {
  const SubmittedScreen({required this.id, this.queued = false, this.site = '', super.key});

  /// Inspection id, or `queued` for a new inspection still in the outbox.
  final String id;
  final bool queued;
  final String site;

  @override
  ConsumerState<SubmittedScreen> createState() => _SubmittedScreenState();
}

class _SubmittedScreenState extends ConsumerState<SubmittedScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  // M3 emphasized decelerate; badge 0–500 ms, text 200–600 ms.
  late final _pop =
      TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.08), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 40),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.71, curve: Easing.emphasizedDecelerate),
        ),
      );
  late final _fade = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5));
  late final _rise = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.29, 0.86, curve: Easing.emphasizedDecelerate),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sharePdf() async {
    final actions = InspectionActions(ref, context);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.pdfFailed;
    try {
      final inspection = await ref.read(inspectionsRepositoryProvider).get(widget.id);
      // Left the screen while the inspection loaded: the export needs this context.
      if (!mounted) return;
      await actions.exportPdf(inspection);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    final known = widget.id != 'queued';
    // A queued edit has an id, but the server doesn't have the new version yet.
    final sent = known && !widget.queued;
    final title = widget.queued ? l.reportQueuedTitle : l.reportSubmittedTitle;
    final detail = [if (known) widget.id, if (widget.site.isNotEmpty) widget.site].join(' · ');
    final body = widget.queued ? l.reportQueuedBody : l.reportSubmittedBody;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const Spacer(),
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _pop,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                        child: Icon(widget.queued ? Symbols.cloud_upload : Symbols.task_alt, size: 56, color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _rise,
                    builder: (context, child) => Opacity(
                      opacity: _rise.value,
                      child: Transform.translate(offset: Offset(0, 16 * (1 - _rise.value)), child: child),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('$detail${detail.isEmpty ? '' : '. '}$body', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (sent) ...[
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => context.go(Routes.inspection(widget.id)),
                      child: Text(l.viewInspection),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: _sharePdf,
                      icon: const Icon(Symbols.picture_as_pdf),
                      label: Text(l.sharePdfReport),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton(onPressed: () => context.go(Routes.inspections), child: Text(l.backToInspections)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
