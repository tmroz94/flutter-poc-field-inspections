import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../data/local/local_store.dart';
import '../../data/models/draft.dart';
import '../../data/providers.dart';
import '../inspections/inspections_controller.dart';

/// Wizard key: `new` for a new inspection, else the inspection id being edited.
String wizardKey(String? inspectionId) => inspectionId ?? 'new';

@immutable
class WizardState {
  const WizardState({required this.draft, this.loading = false, this.savedAt, this.submitting = false, this.submitError});

  final InspectionDraft draft;
  final bool loading;

  /// When the draft was last written to this device (footer "Draft saved").
  final DateTime? savedAt;
  final bool submitting;
  final ApiException? submitError;

  WizardState copyWith({
    InspectionDraft? draft,
    bool? loading,
    DateTime? savedAt,
    bool? submitting,
    ApiException? Function()? submitError,
  }) => WizardState(
    draft: draft ?? this.draft,
    loading: loading ?? this.loading,
    savedAt: savedAt ?? this.savedAt,
    submitting: submitting ?? this.submitting,
    submitError: submitError != null ? submitError() : this.submitError,
  );
}

/// What happened on submit.
enum SubmitOutcome { sent, queued }

/// Loads a saved draft (or prefills from the inspection when editing), saves
/// every change to the device after a short debounce, and submits online or
/// into the outbox when offline.
class WizardController extends Notifier<WizardState> {
  WizardController(this.key);

  final String key;
  Timer? _debounce;

  /// Captured in build: the dispose-time flush can't use `ref` or `state`.
  late LocalStore _store;
  InspectionDraft? _unsaved;

  String? get _inspectionId => key == 'new' ? null : key;

  @override
  WizardState build() {
    _store = ref.read(localStoreProvider);
    ref.onDispose(() {
      _debounce?.cancel();
      // Flush a pending save so nothing typed in the last moment is lost.
      final pending = _unsaved;
      if (pending != null && !(pending.isEmpty && pending.inspectionId == null)) {
        unawaited(_store.saveDraft(key, pending.copyWith(updatedAt: DateTime.now())));
      }
    });
    Future.microtask(_load);
    return WizardState(draft: InspectionDraft(inspectionId: _inspectionId), loading: true);
  }

  Future<void> _load() async {
    var draft = await _store.draft(key);
    if (draft == null && _inspectionId != null) {
      try {
        draft = InspectionDraft.fromInspection(await ref.read(inspectionsRepositoryProvider).get(_inspectionId!));
      } on ApiException {
        draft = InspectionDraft(inspectionId: _inspectionId);
      }
    }
    if (!ref.mounted) return;
    state = WizardState(draft: draft ?? const InspectionDraft(), savedAt: draft?.updatedAt);
  }

  /// Applies [change] and schedules a save.
  void update(InspectionDraft Function(InspectionDraft d) change) {
    state = state.copyWith(draft: change(state.draft), submitError: () => null);
    _unsaved = state.draft;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _persist(state.draft));
  }

  Future<void> saveNow() async {
    _debounce?.cancel();
    await _persist(state.draft);
  }

  Future<void> _persist(InspectionDraft draft) async {
    if (draft.isEmpty && draft.inspectionId == null) return;
    final now = DateTime.now();
    _unsaved = null;
    await _store.saveDraft(key, draft.copyWith(updatedAt: now));
    if (ref.mounted) state = state.copyWith(savedAt: now);
  }

  void reachStep(int step) {
    if (step > state.draft.lastStep) update((d) => d.copyWith(lastStep: step));
  }

  Future<void> discard() async {
    _debounce?.cancel();
    _unsaved = null;
    await _store.deleteDraft(key);
    if (ref.mounted) state = WizardState(draft: InspectionDraft(inspectionId: _inspectionId));
  }

  /// Sends the inspection. Offline (network error) it goes to the outbox and
  /// returns [SubmitOutcome.queued]; the draft is removed either way.
  /// Server validation errors are kept in [WizardState.submitError].
  Future<({SubmitOutcome outcome, String? id})?> submit() async {
    _debounce?.cancel();
    _unsaved = null;
    final draft = state.draft;
    state = state.copyWith(submitting: true, submitError: () => null);
    final store = _store;
    try {
      final saved = await ref.read(inspectionsRepositoryProvider).save(draft.toApiBody(), id: draft.inspectionId, submit: true);
      await store.deleteDraft(key);
      ref
        ..invalidate(inspectionListProvider)
        ..invalidate(homeProvider);
      if (draft.inspectionId != null) ref.invalidate(inspectionDetailProvider(draft.inspectionId!));
      if (ref.mounted) state = state.copyWith(submitting: false);
      return (outcome: SubmitOutcome.sent, id: saved.id);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        await store.enqueue(
          kind: draft.inspectionId == null ? 'create' : 'update',
          inspectionId: draft.inspectionId,
          site: draft.siteName,
          body: draft.toApiBody(),
        );
        await store.deleteDraft(key);
        if (ref.mounted) state = state.copyWith(submitting: false);
        return (outcome: SubmitOutcome.queued, id: draft.inspectionId);
      }
      if (ref.mounted) state = state.copyWith(submitting: false, submitError: () => e);
      return null;
    }
  }
}

final wizardControllerProvider = NotifierProvider.autoDispose.family<WizardController, WizardState, String>(WizardController.new);
