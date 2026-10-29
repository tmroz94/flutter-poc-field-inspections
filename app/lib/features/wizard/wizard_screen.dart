import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/layout/window_size.dart';
import '../../core/router/routes.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/inspection_widgets.dart';
import '../../data/models/draft.dart';
import '../../l10n/l10n.dart';
import '../inspections/inspections_controller.dart';
import 'wizard_controller.dart';
import 'wizard_steps.dart';
import 'wizard_text.dart';
import 'wizard_validation.dart';

/// Lets the wizard route's `onExit` (browser back, links) skip the
/// unsaved-changes dialog after the user already chose to leave or submitted.
class WizardExitApproval extends Notifier<bool> {
  @override
  bool build() => false;

  void approve() => state = true;
  void reset() => state = false;
}

final wizardExitApprovedProvider = NotifierProvider<WizardExitApproval, bool>(WizardExitApproval.new);

enum LeaveChoice { stay, leave, discard }

/// P15: asked when leaving with a draft (close, back, browser back).
Future<LeaveChoice> showLeaveDialog(BuildContext context) async =>
    await showDialog<LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Symbols.edit_note),
        title: Text(context.l10n.leaveTitle),
        content: Text(context.l10n.leaveBody),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, LeaveChoice.discard),
            child: Text(context.l10n.discardDraft),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => Navigator.pop(context, LeaveChoice.stay), child: Text(context.l10n.stay)),
              TextButton(onPressed: () => Navigator.pop(context, LeaveChoice.leave), child: Text(context.l10n.leave)),
            ],
          ),
        ],
      ),
    ) ??
    LeaveChoice.stay;

/// New or edit inspection: 5 steps, step in `?step=` (P09–P13, T02, D04).
class WizardScreen extends ConsumerStatefulWidget {
  const WizardScreen({required this.step, this.inspectionId, this.from, super.key});

  static const stepCount = 5;

  final int step;

  /// Null for a new inspection.
  final String? inspectionId;

  /// Where Close returns to (`?from=`), when the wizard was opened from
  /// somewhere other than its parent page.
  final String? from;

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  /// Steps where Next was pressed, so errors show only after an attempt.
  final Set<WizardStep> _attempted = {};
  final _scroll = ScrollController();

  /// Guard redirect scheduled; avoids one replace per rebuild.
  bool _redirecting = false;

  /// The step the guard last checked: it runs again only when the step changes.
  WizardStep? _checkedStep;

  /// Close was chosen: the page is going away, so the step guard must not
  /// send it back to an earlier step.
  bool _leaving = false;

  /// Why the step guard sent the user back; shown above the step, cleared on
  /// the next move. Inline rather than a snackbar, which would cover the footer.
  String? _notice;

  String get _key => wizardKey(widget.inspectionId);
  WizardStep get _step => WizardStep.fromNumber(widget.step);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(wizardExitApprovedProvider.notifier).reset());
  }

  @override
  void didUpdateWidget(WizardScreen old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step && _scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _location(int step) => widget.inspectionId == null
      ? Routes.newInspectionStep(step, from: widget.from)
      : Routes.editInspection(widget.inspectionId!, step: step, from: widget.from);

  WizardValidator _validator() {
    final items = ref.read(checklistProvider(fireSafetyTemplateId)).value ?? const [];
    return WizardValidator(ValidationText.of(context), today: ref.read(clockProvider)(), checklist: items);
  }

  /// Each step adds a history entry, so browser back returns to the previous step.
  void _goTo(int step) {
    // The draft can't change while it's being sent.
    if (ref.read(wizardControllerProvider(_key)).submitting) return;
    if (_notice != null) setState(() => _notice = null);
    ref.read(wizardControllerProvider(_key).notifier).reachStep(step);
    context.go(_location(step));
  }

  void _next() {
    final draft = ref.read(wizardControllerProvider(_key)).draft;
    final errors = _validator().step(_step, draft);
    if (errors.isNotEmpty) {
      setState(() => _attempted.add(_step));
      // Errors show inline next to each field; a snackbar here would cover the
      // footer buttons, so screen-reader users get an announcement instead.
      SemanticsService.sendAnnouncement(
        View.of(context),
        errors.length == 1 ? errors.values.first : context.l10n.fieldsNeedAttention(errors.length),
        Directionality.of(context),
        assertiveness: Assertiveness.assertive,
      );
      return;
    }
    _goTo(widget.step + 1);
  }

  void _back() => widget.step > 1 ? _goTo(widget.step - 1) : _close();

  Future<void> _close() async {
    final controller = ref.read(wizardControllerProvider(_key).notifier);
    // An untouched wizard with no saved draft has nothing to lose: no question.
    var choice = LeaveChoice.leave;
    if (ref.read(wizardControllerProvider(_key)).hasDraft) choice = await showLeaveDialog(context);
    if (!mounted || choice == LeaveChoice.stay) return;
    _leaving = true;
    if (choice == LeaveChoice.discard) await controller.discard();
    if (choice == LeaveChoice.leave) await controller.saveNow();
    if (!mounted) return;
    ref.read(wizardExitApprovedProvider.notifier).approve();
    if (widget.from != null) {
      context.go(widget.from!);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.inspectionId == null ? Routes.inspections : Routes.inspection(widget.inspectionId!));
    }
  }

  Future<void> _saveDraft() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final saved = await ref.read(wizardControllerProvider(_key).notifier).saveNow();
    messenger.showSnackBar(SnackBar(content: Text(saved ? l.wizardDraftSaved : l.wizardNothingToSave)));
  }

  Future<void> _submit() async {
    final site = ref.read(wizardControllerProvider(_key)).draft.siteName;
    final result = await ref.read(wizardControllerProvider(_key).notifier).submit();
    if (!mounted || result == null) return;
    _leaving = true;
    ref.read(wizardExitApprovedProvider.notifier).approve();
    final queued = result.outcome == SubmitOutcome.queued;
    context.go(Uri(path: Routes.submitted(result.id ?? 'queued'), queryParameters: {if (queued) 'queued': '1', 'site': site}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardControllerProvider(_key));
    // Load the checklist early: steps 3–5 validate against it.
    final checklist = ref.watch(checklistProvider(fireSafetyTemplateId));
    ref.listen(wizardControllerProvider(_key).select((s) => s.recoveredPhoto), (_, recovered) {
      if (recovered) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.wizardRecoveredPhoto)));
    });
    final size = context.windowSize;
    final l = context.l10n;
    final title = widget.inspectionId == null ? l.newInspection : l.editInspection(widget.inspectionId!);

    if (state.loading || state.loadError != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: l.close, onPressed: _close, icon: const Icon(Symbols.close)),
          title: Text(title),
        ),
        body: Center(
          child: state.loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.wizardLoadFailed, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: ref.read(wizardControllerProvider(_key).notifier).reload, child: Text(l.tryAgain)),
                    ],
                  ),
                ),
        ),
      );
    }

    // Step guard: a step can't be opened while an earlier step is invalid.
    // Checked when a step opens (a link, back/forward, the step bar), not on
    // every edit: removing a failed item's only photo on step 4 mustn't throw
    // the user back to step 3 mid-edit (Submit still checks every step). Not
    // before the checklist has loaded (step 3 depends on it), and not while
    // the wizard is closing.
    final checkNow = !checklist.isLoading && !_leaving && _checkedStep != _step;
    final blockedAt = checkNow ? _validator().firstInvalidBefore(_step, state.draft) : null;
    if (checkNow) _checkedStep = _step;
    if (blockedAt != null && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _leaving || !(ModalRoute.of(context)?.isCurrent ?? false)) {
          _redirecting = false;
          // Not redirected (e.g. a sheet is on top): check again on the next build.
          _checkedStep = null;
          return;
        }
        final notice = context.l10n.completeStepFirst(stepTitle(context, blockedAt));
        setState(() {
          _attempted.add(blockedAt);
          _notice = notice;
        });
        context.go(_location(blockedAt.number));
        SemanticsService.sendAnnouncement(View.of(context), notice, Directionality.of(context), assertiveness: Assertiveness.assertive);
      });
    } else if (blockedAt == null) {
      _redirecting = false;
    }

    final errors = _attempted.contains(_step) ? _validator().step(_step, state.draft) : const <String, String>{};
    final stepView = WizardStepView(step: _step, wizardKey: _key, errors: errors, onEditStep: _goTo, onSubmit: _submit);
    final content = _notice == null
        ? stepView
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_Notice(_notice!), const SizedBox(height: 16), stepView]);
    final savedAt = state.savedAt;
    final savedText = savedAt == null
        ? null
        : l.draftSavedAt(DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(savedAt));

    final appBar = AppBar(
      leading: IconButton(tooltip: l.close, onPressed: _close, icon: const Icon(Symbols.close)),
      title: Text(title),
      actions: [
        if (size.isTwoPane && savedText != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Icon(Symbols.cloud_done, size: 16),
                const SizedBox(width: 4),
                Text(savedText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        TextButton(onPressed: state.submitting ? null : _saveDraft, child: Text(context.l10n.saveDraft)),
      ],
    );

    final isLast = _step == WizardStep.review;
    final footer = _Footer(
      savedText: size.isTwoPane || isLast ? null : savedText,
      onBack: widget.step > 1 ? _back : null,
      onNext: isLast ? null : _next,
      nextLabel: size.isTwoPane && !isLast
          ? context.l10n.nextStep(stepTitle(context, WizardStep.fromNumber(widget.step + 1)))
          : context.l10n.next,
      alignEnd: size.isTwoPane,
    );

    final body = switch (size) {
      WindowSize.compact || WindowSize.medium => Column(
        children: [
          _PhoneStepHeader(step: _step),
          Expanded(
            child: SingleChildScrollView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), child: content),
          ),
          footer,
        ],
      ),
      WindowSize.expanded => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VerticalSteps(current: _step, draft: state.draft, validator: _validator(), onTap: _goTo),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
                    child: _MainHeader(step: _step, child: content),
                  ),
                ),
                footer,
              ],
            ),
          ),
        ],
      ),
      WindowSize.large => Column(
        children: [
          _HorizontalSteps(current: _step, draft: state.draft, validator: _validator(), onTap: _goTo),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: _MainHeader(step: _step, child: content),
                ),
              ),
            ),
          ),
          footer,
        ],
      ),
    };

    return PopScope(
      canPop: false,
      // System back (Android, iOS swipe): previous step, or the leave dialog on step 1.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: appBar,
        body: SafeArea(top: false, child: body),
      ),
    );
  }
}

class _PhoneStepHeader extends StatelessWidget {
  const _PhoneStepHeader({required this.step});

  final WizardStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(stepTitle(context, step), style: theme.textTheme.titleMedium)),
              ),
              Text(
                context.l10n.stepOf(step.number, WizardScreen.stepCount),
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(end: step.number / WizardScreen.stepCount),
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Durations.medium2,
            curve: Easing.emphasizedDecelerate,
            builder: (_, value, _) =>
                LinearProgressIndicator(value: value, borderRadius: BorderRadius.circular(4), semanticsLabel: context.l10n.wizardProgress),
          ),
        ],
      ),
    );
  }
}

class _MainHeader extends StatelessWidget {
  const _MainHeader({required this.step, required this.child});

  final WizardStep step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.stepOf(step.number, WizardScreen.stepCount),
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Semantics(header: true, child: Text(stepTitle(context, step), style: theme.textTheme.headlineSmall)),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

enum _StepState { done, current, upcoming, attention }

_StepState _stateOf(WizardStep s, WizardStep current, InspectionDraft draft, WizardValidator v) {
  if (s == current) return _StepState.current;
  if (s.number > draft.lastStep) return _StepState.upcoming;
  return v.step(s, draft).isEmpty ? _StepState.done : _StepState.attention;
}

/// "Details, done": the state the dot shows only by icon and colour.
String _stepSemantics(BuildContext context, WizardStep s, _StepState state) {
  final l = context.l10n;
  final title = stepTitle(context, s);
  return switch (state) {
    _StepState.done => l.stepStateDone(title),
    _StepState.attention => l.stepStateAttention(title),
    _StepState.current => l.stepStateCurrent(title),
    _StepState.upcoming => l.stepStateUpcoming(title),
  };
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.state, this.size = 32});

  final WizardStep step;
  final _StepState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = state == _StepState.done || state == _StepState.current;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) {
          _StepState.attention => scheme.errorContainer,
          _ when filled => scheme.primary,
          _ => null,
        },
        border: filled || state == _StepState.attention ? null : Border.all(color: scheme.outline),
      ),
      child: switch (state) {
        _StepState.done => Icon(Symbols.check, size: 18, color: scheme.onPrimary),
        _StepState.attention => Icon(Symbols.priority_high, size: 18, color: scheme.onErrorContainer),
        _StepState.current => Text('${step.number}', style: TextStyle(color: scheme.onPrimary)),
        _StepState.upcoming => Text('${step.number}', style: TextStyle(color: scheme.onSurfaceVariant)),
      },
    );
  }
}

/// T02: steps down the side with a one-line hint each.
class _VerticalSteps extends StatelessWidget {
  const _VerticalSteps({required this.current, required this.draft, required this.validator, required this.onTap});

  final WizardStep current;
  final InspectionDraft draft;
  final WizardValidator validator;
  final ValueChanged<int> onTap;

  String _hint(BuildContext context, WizardStep s) {
    final l = context.l10n;
    final errors = validator.step(s, draft).length;
    if (errors > 0 && s.number <= draft.lastStep && s != current) return l.fieldsNeedAttention(errors);
    return switch (s) {
      WizardStep.site => draft.siteName.isEmpty ? l.wizardHintSite : draft.siteName,
      WizardStep.details => draft.type ?? l.wizardHintDetails,
      WizardStep.checklist => l.wizardHintChecklist(draft.answers.length, validator.checklist.length),
      WizardStep.photos => l.wizardHintPhotos(draft.photos.length, draft.files.length),
      WizardStep.review => l.wizardHintReview,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: 300,
        // A landscape phone counts as wide but has ~330 dp under the app bar.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              for (final s in WizardStep.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Semantics(
                    label: _stepSemantics(context, s, _stateOf(s, current, draft, validator)),
                    child: ListTile(
                      selected: s == current,
                      selectedTileColor: theme.colorScheme.secondaryContainer,
                      shape: const StadiumBorder(),
                      enabled: s.number <= draft.lastStep || s == current,
                      onTap: () => onTap(s.number),
                      leading: ExcludeSemantics(
                        child: _StepDot(step: s, state: _stateOf(s, current, draft, validator)),
                      ),
                      title: ExcludeSemantics(child: Text(stepTitle(context, s), style: theme.textTheme.titleSmall)),
                      subtitle: Text(_hint(context, s), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D04: horizontal stepper under the app bar.
class _HorizontalSteps extends StatelessWidget {
  const _HorizontalSteps({required this.current, required this.draft, required this.validator, required this.onTap});

  final WizardStep current;
  final InspectionDraft draft;
  final WizardValidator validator;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: context.l10n.wizardSteps,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in WizardStep.values) ...[
              Semantics(
                button: s.number <= draft.lastStep,
                selected: s == current,
                label: _stepSemantics(context, s, _stateOf(s, current, draft, validator)),
                // excludeSemantics drops the InkWell's own action: give it back here.
                onTap: s.number <= draft.lastStep ? () => onTap(s.number) : null,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: s.number <= draft.lastStep ? () => onTap(s.number) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepDot(step: s, state: _stateOf(s, current, draft, validator), size: 28),
                        const SizedBox(width: 8),
                        Text(
                          stepTitle(context, s),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: s == current ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (s != WizardStep.review) Container(width: 48, height: 1, color: theme.colorScheme.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Symbols.info, color: c.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: c.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.savedText, required this.onBack, required this.onNext, required this.nextLabel, required this.alignEnd});

  final String? savedText;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final back = OutlinedButton(onPressed: onBack, child: Text(context.l10n.back));
    final next = onNext == null ? null : FilledButton(onPressed: onNext, child: Text(nextLabel));
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (savedText != null) ...[
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(Symbols.cloud_done, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(savedText!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (alignEnd)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  back,
                  if (next != null) ...[const SizedBox(width: 8), next],
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: back),
                  if (next != null) ...[const SizedBox(width: 8), Expanded(child: next)],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
