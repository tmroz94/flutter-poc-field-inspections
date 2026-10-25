import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/models/inspection.dart';
import '../../l10n/l10n.dart';
import 'inspection_actions.dart';
import 'inspection_detail_screen.dart';
import 'inspections_controller.dart';

/// P08: full-screen, always dark. Swipe between photos, pinch or double-tap to
/// zoom, arrow keys and Esc on keyboards. The URL follows the current photo.
class PhotoViewerScreen extends ConsumerWidget {
  const PhotoViewerScreen({required this.inspectionId, required this.photoId, super.key});

  final String inspectionId;
  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = buildTheme(colorSchemeFor(Brightness.dark, AppContrast.standard), reduceMotion: MediaQuery.disableAnimationsOf(context));
    final detail = ref.watch(inspectionDetailProvider(inspectionId));
    return Theme(
      data: theme,
      child: switch (detail) {
        AsyncData(:final value) when value.photos.any((p) => p.id == photoId) => _Viewer(detail: value, photoId: photoId),
        AsyncData() || AsyncError() => Scaffold(
          appBar: AppBar(
            leading: CloseButton(onPressed: () => context.go(Routes.inspection(inspectionId, tab: 'photos'))),
          ),
          body: MessageState(
            icon: Symbols.hide_image,
            title: context.l10n.photoNotFound,
            message: context.l10n.photoNotFoundBody(photoId, inspectionId),
          ),
        ),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}

class _Viewer extends ConsumerStatefulWidget {
  const _Viewer({required this.detail, required this.photoId});

  final InspectionDetail detail;
  final String photoId;

  @override
  ConsumerState<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends ConsumerState<_Viewer> {
  late int _index = widget.detail.photos.indexWhere((p) => p.id == widget.photoId);
  late final _pages = PageController(initialPage: _index);
  final _zoom = TransformationController();
  TapDownDetails? _doubleTap;

  List<Photo> get _photos => widget.detail.photos;

  @override
  void dispose() {
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    setState(() => _index = i);
    _zoom.value = Matrix4.identity();
    // Keep the URL on the visible photo without adding history entries.
    GoRouter.of(context).replace<void>(Routes.photo(widget.detail.id, _photos[i].id));
  }

  void _toggleZoom() {
    if (_zoom.value != Matrix4.identity()) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final p = _doubleTap?.localPosition ?? Offset.zero;
    const s = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (s - 1), -p.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void _close() => context.canPop() ? context.pop() : context.go(detailLocation(context, widget.detail.id, DetailTab.photos));

  /// Page being animated to, so quick repeated key presses add up.
  int? _target;

  Future<void> _step(int delta) async {
    final next = ((_target ?? _index) + delta).clamp(0, _photos.length - 1);
    if (next == (_target ?? _index)) return;
    _target = next;
    await _pages.animateToPage(next, duration: Durations.medium2, curve: Easing.standard);
    if (_target == next) _target = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final photo = _photos[_index];
    final meta = [
      DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(photo.takenAt),
      if (photo.lat != null && photo.lng != null) '${photo.lat!.toStringAsFixed(4)}° N, ${photo.lng!.toStringAsFixed(4)}° E',
      if (photo.sizeBytes > 0) '${(photo.sizeBytes / 1e6).toStringAsFixed(1)} MB',
    ].join(' · ');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(tooltip: l.closeViewer, onPressed: _close, icon: const Icon(Symbols.close)),
            title: Text(l.photoCounter(_index + 1, _photos.length)),
            actions: [
              IconButton(
                tooltip: l.sharePhoto,
                onPressed: () =>
                    InspectionActions(ref, context).share(widget.detail.summary, paths: [Routes.photo(widget.detail.id, photo.id)]),
                icon: const Icon(Symbols.share),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _photos.length,
                  onPageChanged: _onPage,
                  itemBuilder: (context, i) => Center(
                    child: GestureDetector(
                      onDoubleTapDown: (d) => _doubleTap = d,
                      onDoubleTap: _toggleZoom,
                      child: InteractiveViewer(
                        transformationController: i == _index ? _zoom : null,
                        maxScale: 5,
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Semantics(
                            image: true,
                            label: l.photoCaption(i + 1, _photos[i].caption),
                            child: Hero(
                              tag: 'photo-${widget.detail.id}-${_photos[i].id}',
                              child: PhotoImage(photoId: _photos[i].id, index: i, iconSize: 64, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PageIndicator(count: _photos.length, index: _index),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(photo.caption, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One dot per photo; a "3 of 12" counter above 10 (docs/decisions.md #15).
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (count > 10) return Text(context.l10n.photoCounter(index + 1, count));
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Durations.short4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: i == index ? scheme.primary : scheme.outline, borderRadius: BorderRadius.circular(3)),
            ),
        ],
      ),
    );
  }
}
