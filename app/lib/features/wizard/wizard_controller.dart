import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_services.dart';
import '../../core/storage/key_value_store.dart';
import '../../data/api/api_exception.dart';
import '../../data/local/local_store.dart';
import '../../data/models/draft.dart';
import '../../data/providers.dart';
import '../inspections/inspections_controller.dart';
import 'wizard_validation.dart';

/// Wizard key: `new` for a new inspection, else the inspection id being edited.
String wizardKey(String? inspectionId) => inspectionId ?? 'new';

final _random = Random();

/// Unique on every platform: the web clock has millisecond resolution, so
/// several files dropped at once would otherwise share an id (and a blob).
/// (Not `1 << 32` for the bound: compiled to JavaScript that is 0.)
String newAttachmentId({required bool photo}) =>
    '${photo ? 'ph' : 'f'}-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(0xFFFFFFFF).toRadixString(36)}';

/// One per new inspection, made on its first submit and kept with the draft
/// until a submit succeeds: every attempt and, if one fails for lack of
/// network, the outbox entry send the same key, so the server makes one
/// inspection even when an answer was lost.
String newRequestKey() =>
    'sub-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(0xFFFFFFFF).toRadixString(36)}-${_random.nextInt(0xFFFFFFFF).toRadixString(36)}';

@immutable
class WizardState {
  const WizardState({
    required this.draft,
    this.loading = false,
    this.savedAt,
    this.submitting = false,
    this.submitError,
    this.loadError,
    this.changed = false,
    this.stored = false,
    this.recoveredPhoto = false,
  });

  final InspectionDraft draft;
  final bool loading;

  /// When the draft was last written to this device (footer "Draft saved").
  final DateTime? savedAt;
  final bool submitting;
  final ApiException? submitError;

  /// The inspection to edit couldn't be loaded (e.g. offline): the wizard
  /// shows a retry instead of an empty form that would be saved as a draft.
  final Object? loadError;

  /// The user changed something since the wizard opened.
  final bool changed;

  /// A draft of this wizard is saved on the device.
  final bool stored;

  /// Something to keep or discard when leaving: an untouched wizard (e.g. an
  /// edit opened from the inspection) closes without asking or saving.
  bool get hasDraft => changed || stored;

  /// A camera photo from before Android restarted the app was just added.
  final bool recoveredPhoto;

  WizardState copyWith({
    InspectionDraft? draft,
    bool? loading,
    DateTime? Function()? savedAt,
    bool? submitting,
    ApiException? Function()? submitError,
    Object? Function()? loadError,
    bool? changed,
    bool? stored,
    bool? recoveredPhoto,
  }) => WizardState(
    draft: draft ?? this.draft,
    loading: loading ?? this.loading,
    savedAt: savedAt != null ? savedAt() : this.savedAt,
    submitting: submitting ?? this.submitting,
    submitError: submitError != null ? submitError() : this.submitError,
    loadError: loadError != null ? loadError() : this.loadError,
    changed: changed ?? this.changed,
    stored: stored ?? this.stored,
    recoveredPhoto: recoveredPhoto ?? this.recoveredPhoto,
  );
}

/// What happened on submit.
enum SubmitOutcome { sent, queued }

/// Loads a saved draft (or prefills from the inspection when editing), saves
/// changes to the device after a short debounce, and submits online or into
/// the outbox when offline.
class WizardController extends Notifier<WizardState> {
  WizardController(this.key);

  final String key;
  Timer? _debounce;

  /// Captured in build: the dispose-time flush can't use `ref` or `state`.
  late LocalStore _store;
  late KeyValueStore _kv;
  InspectionDraft? _unsaved;

  /// The draft was already on the device when the wizard opened.
  bool _stored = false;

  String? get _inspectionId => key == 'new' ? null : key;

  @override
  WizardState build() {
    _store = ref.read(localStoreProvider);
    _kv = ref.read(keyValueStoreProvider);
    ref.onDispose(() {
      _debounce?.cancel();
      // Flush a pending save so nothing typed in the last moment is lost
      // ([update] only leaves one when the draft is worth saving).
      final pending = _unsaved;
      if (pending != null) {
        unawaited(_store.saveDraft(key, pending.copyWith(updatedAt: DateTime.now())));
      }
    });
    Future.microtask(_load);
    return WizardState(draft: InspectionDraft(inspectionId: _inspectionId), loading: true);
  }

  Future<void> _load() async {
    InspectionDraft? draft;
    Object? error;
    try {
      draft = await _store.draft(key);
      _stored = draft != null;
      if (draft == null && _inspectionId != null && ref.mounted) {
        draft = InspectionDraft.fromInspection(await ref.read(inspectionsRepositoryProvider).get(_inspectionId!));
      }
    } on Object catch (e) {
      error = e;
    }
    if (!ref.mounted) return;
    state = WizardState(
      draft: draft ?? InspectionDraft(inspectionId: _inspectionId),
      savedAt: _stored ? draft?.updatedAt : null,
      loadError: error,
      stored: _stored,
    );
    if (error == null) await _recoverLostPhoto();
  }

  /// After [WizardState.loadError]: try loading the inspection again.
  Future<void> reload() async {
    state = state.copyWith(loading: true, loadError: () => null);
    await _load();
  }

  static const _cameraKey = 'wizard.cameraFor';

  /// Notes which wizard (and checklist item) the system camera opens for: if
  /// Android restarts the app meanwhile, only that wizard takes the photo.
  Future<void> cameraOpening({String? forItem}) => _kv.setString(_cameraKey, jsonEncode({'key': key, 'forItem': forItem}));

  Future<void> cameraClosed() => _kv.remove(_cameraKey);

  Future<void> _recoverLostPhoto() async {
    String? forItem;
    if (_kv.getString(_cameraKey) case final raw?) {
      final Map<String, Object?> target;
      try {
        target = (jsonDecode(raw) as Map).cast<String, Object?>();
      } on Object {
        await cameraClosed();
        return;
      }
      // Another wizard's photo: left for that one to pick up.
      if (target['key'] != key) return;
      forItem = target['forItem'] as String?;
    }
    final file = await ref.read(mediaServiceProvider).lostPhoto();
    await cameraClosed();
    if (file == null || !ref.mounted) return;
    if (await addFile(file, forItem: forItem) && ref.mounted) state = state.copyWith(recoveredPhoto: true);
  }

  /// A draft is kept once the user changed something, or when it was already
  /// stored; never an untouched new one.
  bool _worthSaving(InspectionDraft d) => (state.changed || _stored) && !(d.isEmpty && d.inspectionId == null);

  /// Applies [change] and schedules a save. [byUser] false (step bookkeeping)
  /// doesn't count as a change on its own. Ignored while a submit runs (the
  /// draft being sent can't change underneath it) and once the wizard closed
  /// (a late location fix).
  void update(InspectionDraft Function(InspectionDraft d) change, {bool byUser = true}) {
    if (!ref.mounted || state.submitting) return;
    state = state.copyWith(draft: change(state.draft), submitError: () => null, changed: state.changed || byUser);
    _debounce?.cancel();
    if (!_worthSaving(state.draft)) {
      _unsaved = null;
      // A saved new draft that was emptied again goes, rather than coming back next time.
      if (_stored && state.draft.inspectionId == null) unawaited(_forget());
      return;
    }
    _unsaved = state.draft;
    _debounce = Timer(const Duration(milliseconds: 400), () => _persist(state.draft));
  }

  /// False when nothing was written: nothing worth keeping yet, or a submit runs.
  Future<bool> saveNow() async {
    _debounce?.cancel();
    return _persist(state.draft);
  }

  Future<bool> _persist(InspectionDraft draft) async {
    if (state.submitting || !_worthSaving(draft)) return false;
    final now = DateTime.now();
    _unsaved = null;
    await _store.saveDraft(key, draft.copyWith(updatedAt: now));
    _stored = true;
    if (ref.mounted) state = state.copyWith(savedAt: () => now, stored: true);
    return true;
  }

  Future<void> _forget() async {
    _stored = false;
    await _store.deleteDraft(key);
    if (ref.mounted) state = state.copyWith(savedAt: () => null, stored: false);
  }

  void reachStep(int step) {
    if (step > state.draft.lastStep) update((d) => d.copyWith(lastStep: step), byUser: false);
  }

  /// Saves picked bytes on the device (SQLite blob) and adds the attachment.
  /// False when the type or size isn't allowed, or the wizard closed meanwhile.
  Future<bool> addFile(PickedFile file, {String? forItem}) async {
    final ext = file.name.split('.').last.toLowerCase();
    if (!WizardValidator.allowedExtensions.contains(ext) || file.bytes.length > WizardValidator.maxFileBytes) return false;
    final id = newAttachmentId(photo: file.isImage);
    await _store.putBlob(id, file.bytes, file.mime);
    if (!ref.mounted) {
      await _store.deleteBlob(id);
      return false;
    }
    update(
      (d) => d.copyWith(
        attachments: [
          ...d.attachments,
          DraftAttachment(id: id, name: file.name, sizeBytes: file.bytes.length, isPhoto: file.isImage, forItem: forItem),
        ],
      ),
    );
    return true;
  }

  void removeAttachment(DraftAttachment a) {
    update((d) => d.copyWith(attachments: d.attachments.where((x) => x.id != a.id).toList()));
    // Bytes only exist for files added on this device.
    if (!a.stored) unawaited(_store.deleteBlob(a.id));
  }

  /// Deletes the draft and its stored files. The wizard is closing, so the
  /// state is left as it is (an emptied draft would re-run the step guard).
  /// While a submit runs the draft stays: the submit removes it once sent or
  /// queued, and it's still needed if the server rejects it.
  Future<void> discard() async {
    if (state.submitting) return;
    _debounce?.cancel();
    _unsaved = null;
    final attachments = state.draft.attachments;
    await _store.deleteDraft(key);
    for (final a in attachments) {
      if (!a.stored) await _store.deleteBlob(a.id);
    }
    _stored = false;
  }

  /// Sends the inspection. Offline (network error) it goes to the outbox and
  /// returns [SubmitOutcome.queued]; the draft is removed either way. Server
  /// validation errors are kept in [WizardState.submitError]. Safe to leave
  /// the wizard while it runs.
  Future<({SubmitOutcome outcome, String? id})?> submit() async {
    _debounce?.cancel();
    _unsaved = null;
    var draft = state.draft;
    final firstTry = draft.inspectionId == null && draft.requestKey == null;
    if (firstTry) draft = draft.copyWith(requestKey: newRequestKey());
    final requestKey = draft.requestKey;
    final store = _store;
    final repository = ref.read(inspectionsRepositoryProvider);
    final revision = ref.read(inspectionsRevisionProvider.notifier);
    state = state.copyWith(draft: draft, submitting: true, submitError: () => null);
    try {
      // The key goes into the saved draft, so a retry after leaving reuses it.
      if (firstTry) {
        await store.saveDraft(key, draft.copyWith(updatedAt: DateTime.now()));
        _stored = true;
      }
      final saved = await repository.save(draft.toApiBody(), id: draft.inspectionId, submit: true, requestKey: requestKey);
      await store.deleteDraft(key);
      revision.changed();
      return (outcome: SubmitOutcome.sent, id: saved.id);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        await store.enqueue(
          kind: draft.inspectionId == null ? 'create' : 'update',
          inspectionId: draft.inspectionId,
          site: draft.siteName,
          body: draft.toApiBody(),
          draft: draft,
          requestKey: requestKey,
        );
        await store.deleteDraft(key);
        return (outcome: SubmitOutcome.queued, id: draft.inspectionId);
      }
      if (ref.mounted) state = state.copyWith(submitError: () => e);
      return null;
    } on Object catch (e) {
      debugPrint('Submit failed: $e');
      if (ref.mounted) state = state.copyWith(submitError: () => const ApiException('unknown'));
      return null;
    } finally {
      if (ref.mounted) state = state.copyWith(submitting: false);
    }
  }
}

final wizardControllerProvider = NotifierProvider.autoDispose.family<WizardController, WizardState, String>(WizardController.new);
