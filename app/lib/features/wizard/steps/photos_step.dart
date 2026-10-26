import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/platform/capabilities.dart';
import '../../../core/platform/platform_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/local_store.dart';
import '../../../data/models/draft.dart';
import '../../../l10n/l10n.dart';
import '../../inspections/inspection_detail_screen.dart' show PhotoPlaceholder;
import '../wizard_controller.dart';

// ------------------------------------------------------- Step 4: Photos, files

enum CaptureResult { added, cancelled, rejected, denied, failed }

/// Camera or gallery into the draft. Handles cancel and a denied camera.
Future<CaptureResult> addPickedPhoto(WidgetRef ref, BuildContext context, String wizardKey, {required bool camera, String? forItem}) async {
  final wizard = ref.read(wizardControllerProvider(wizardKey).notifier);
  final media = ref.read(mediaServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  try {
    final file = await media.photo(camera: camera);
    if (file == null) return CaptureResult.cancelled;
    final ok = await wizard.addFile(file, forItem: forItem);
    if (!ok && context.mounted) messenger.showSnackBar(SnackBar(content: Text(l.photoTypeHint)));
    return ok ? CaptureResult.added : CaptureResult.rejected;
  } on PlatformException catch (e) {
    // iOS reports camera_access_denied / photo_access_denied.
    if (e.code.contains('access_denied')) return CaptureResult.denied;
    if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(camera ? l.cameraOpenFailed : l.galleryOpenFailed)));
    return CaptureResult.failed;
  }
}

/// A saved photo, or the placeholder for simulated, fixture or server photos.
class AttachmentImage extends ConsumerWidget {
  const AttachmentImage({required this.attachment, required this.index, super.key});

  final DraftAttachment attachment;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(blobProvider(attachment.id)).value;
    if (bytes == null) return PhotoPlaceholder(index: index);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        semanticLabel: attachment.name,
        errorBuilder: (_, _, _) => PhotoPlaceholder(index: index),
      ),
    );
  }
}

/// P12 / D04: camera, gallery, files, drag and drop, and paste on the web.
class PhotosStep extends ConsumerStatefulWidget {
  const PhotosStep({required this.wizardKey, required this.errors, super.key});

  final String wizardKey;
  final Map<String, String> errors;

  @override
  ConsumerState<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<PhotosStep> {
  final _grid = GlobalKey<SliverAnimatedGridState>();
  late List<DraftAttachment> _shown = ref.read(wizardControllerProvider(widget.wizardKey)).draft.photos;
  bool _cameraDenied = false;
  bool _dragging = false;
  void Function()? _stopPaste;

  @override
  void initState() {
    super.initState();
    // Web: Ctrl/Cmd+V of a screenshot or copied image adds it (D04 "Paste image").
    if (ref.read(capabilitiesProvider).isWeb) _stopPaste = ref.read(mediaServiceProvider).onPaste(_add);
  }

  @override
  void dispose() {
    _stopPaste?.call();
    super.dispose();
  }

  Duration get _duration => MediaQuery.disableAnimationsOf(context) ? Duration.zero : Durations.medium2;

  WizardController get _wizard => ref.read(wizardControllerProvider(widget.wizardKey).notifier);

  /// Keeps the animated grid in step with photos added elsewhere (drop, paste).
  void _syncGrid(List<DraftAttachment> photos) {
    for (final p in photos) {
      if (!_shown.any((s) => s.id == p.id)) {
        _shown = [..._shown, p];
        _grid.currentState?.insertItem(_shown.length - 1, duration: _duration);
      }
    }
  }

  Future<void> _add(PickedFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final rejected = context.l10n.fileRejected(file.name);
    if (!await _wizard.addFile(file) && mounted) messenger.showSnackBar(SnackBar(content: Text(rejected)));
  }

  Future<void> _capture({required bool camera}) async {
    final result = await addPickedPhoto(ref, context, widget.wizardKey, camera: camera);
    if (result == CaptureResult.denied && mounted) setState(() => _cameraDenied = true);
  }

  Future<void> _attachFiles() async {
    for (final f in await ref.read(mediaServiceProvider).files()) {
      if (!mounted) return;
      await _add(f);
    }
  }

  void _remove(DraftAttachment photo) {
    final index = _shown.indexWhere((p) => p.id == photo.id);
    if (index < 0) return;
    _wizard.removeAttachment(photo);
    _shown = [..._shown]..removeAt(index);
    _grid.currentState?.removeItem(index, (context, animation) => _tile(context, photo, index, animation), duration: _duration);
  }

  Widget _tile(BuildContext context, DraftAttachment p, int index, Animation<double> animation) {
    final l = context.l10n;
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Easing.emphasizedDecelerate),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Semantics(
            label: p.forItem != null ? l.photoNForFailure(index + 1) : l.photoN(index + 1),
            child: AttachmentImage(attachment: p, index: index),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton.filled(
              tooltip: l.removePhotoN(index + 1),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
                minimumSize: const Size(28, 28),
                iconSize: 18,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: () => _remove(p),
              icon: const Icon(Symbols.close),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(wizardControllerProvider(widget.wizardKey)).draft;
    _syncGrid(d.photos);
    final theme = Theme.of(context);
    final l = context.l10n;
    final caps = ref.watch(capabilitiesProvider);
    final e = widget.errors;

    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (caps.camera)
          FilledButton.tonalIcon(
            onPressed: _cameraDenied ? null : () => _capture(camera: true),
            icon: const Icon(Symbols.photo_camera),
            label: Text(caps.isWeb ? l.useCamera : l.takePhoto),
          ),
        OutlinedButton.icon(onPressed: () => _capture(camera: false), icon: const Icon(Symbols.photo_library), label: Text(l.gallery)),
      ],
    );

    // Pointer platforms get a drop zone (D04); phones and tablets get buttons.
    final zone = DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        for (final f in detail.files) {
          final file = PickedFile(name: f.name, bytes: await f.readAsBytes(), mime: mimeFor(f.name));
          if (!mounted) return;
          await _add(file);
        }
      },
      child: AnimatedContainer(
        duration: _duration,
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _dragging ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: _dragging ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: _dragging ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(Symbols.upload, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              _dragging
                  ? l.dropFiles
                  : caps.isWeb
                  ? l.dragOrPaste
                  : l.dragFiles,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(l.fileTypesHint, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            buttons,
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.photosIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (_cameraDenied) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(AppRadii.medium)),
            child: Row(
              children: [
                Icon(Symbols.no_photography, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.cameraOff, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
                if (caps.openSystemSettings)
                  TextButton(onPressed: () => ref.read(permissionServiceProvider).openSettings(), child: Text(l.openSettings)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (caps.isMobile) buttons else zone,
        const SizedBox(height: 16),
        Text(l.photosCount(d.photos.length), style: theme.textTheme.titleSmall),
        if (e['photos'] != null) Text(e['photos']!, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 8),
        CustomScrollView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(6),
              sliver: SliverAnimatedGrid(
                key: _grid,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                initialItemCount: _shown.length,
                itemBuilder: (context, i, animation) => _tile(context, _shown[i], i, animation),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(l.filesCount(d.files.length), style: theme.textTheme.titleSmall)),
            TextButton.icon(onPressed: _attachFiles, icon: const Icon(Symbols.attach_file), label: Text(l.attachFile)),
          ],
        ),
        for (final f in d.files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(f.name.toLowerCase().endsWith('.pdf') ? Symbols.picture_as_pdf : Symbols.draft),
            title: Text(f.name),
            subtitle: Text(f.stored ? l.fileOnServer((f.sizeBytes / 1000).round()) : l.fileSavedOnDevice((f.sizeBytes / 1000).round())),
            trailing: IconButton(
              tooltip: l.removeFile(f.name),
              onPressed: () => _wizard.removeAttachment(f),
              icon: const Icon(Symbols.close),
            ),
          ),
        for (final key in ['size', 'type'])
          if (e[key] != null) Text(e[key]!, style: TextStyle(color: theme.colorScheme.error)),
      ],
    );
  }
}
