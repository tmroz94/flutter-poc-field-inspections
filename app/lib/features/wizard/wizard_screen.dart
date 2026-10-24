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
import '../inspections/inspections_controller.dart';
import 'wizard_controller.dart';
import 'wizard_steps.dart';
import 'wizard_validation.dart';

/// Template every new inspection uses in the PoC (see fixtures).
const fireSafetyTemplateId = 'tpl-fire-annual-v3';

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
        title: const Text('Leave without submitting?'),
        content: const Text('Your answers are saved as a draft on this device. You can finish it later from Home.'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, LeaveChoice.discard),
            child: const Text('Discard draft'),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => Navigator.pop(context, LeaveChoice.stay), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(context, LeaveChoice.leave), child: const Text('Leave')),
            ],
          ),
        ],
      ),
    ) ??
    LeaveChoice.stay;

/// New or edit inspection: 5 steps, step in `?step=` (P09–P13, T02, D04).
class WizardScreen extends ConsumerStatefulWidget {
  const WizardScreen({required this.step, this.inspectionId, super.key});

  static const stepCount = 5;

  final int step;

  /// Null for a new inspection.
  final String? inspectionId;

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  /// Steps where Next was pressed, so errors show only after an attempt.
  final Set<WizardStep> _attempted = {};
  final _scroll = ScrollController();

  /// Guard redirect scheduled; avoids one replace per rebuild.
  bool _redirecting = false;

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

  String _location(int step) =>
      widget.inspectionId == null ? Routes.newInspectionStep(step) : Routes.editInspection(widget.inspectionId!, step: step);

  WizardValidator _validator() {
    final items = ref.read(checklistProvider(fireSafetyTemplateId)).value ?? const [];
    return WizardValidator(ValidationText.of(context), today: ref.read(clockProvider)(), checklist: items);
  }

  /// Each step adds a history entry, so browser back returns to the previous step.
  void _goTo(int step) {
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
        errors.length == 1 ? errors.values.first : '${errors.length} fields need attention',
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
    final draft = ref.read(wizardControllerProvider(_key)).draft;
    var choice = LeaveChoice.leave;
    if (!draft.isEmpty) choice = await showLeaveDialog(context);
    if (!mounted || choice == LeaveChoice.stay) return;
    if (choice == LeaveChoice.discard) await controller.discard();
    if (choice == LeaveChoice.leave) await controller.saveNow();
    if (!mounted) return;
    ref.read(wizardExitApprovedProvider.notifier).approve();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.inspectionId == null ? Routes.inspections : Routes.inspection(widget.inspectionId!));
    }
  }

  Future<void> _saveDraft() async {
    await ref.read(wizardControllerProvider(_key).notifier).saveNow();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved on this device')));
  }

  Future<void> _submit() async {
    final result = await ref.read(wizardControllerProvider(_key).notifier).submit();
    if (!mounted || result == null) return;
    ref.read(wizardExitApprovedProvider.notifier).approve();
    final queued = result.outcome == SubmitOutcome.queued;
    final draft = ref.read(wizardControllerProvider(_key)).draft;
    context.go(
      Uri(path: Routes.submitted(result.id ?? 'queued'), queryParameters: {if (queued) 'queued': '1', 'site': draft.siteName}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wizardControllerProvider(_key));
    // Load the checklist early: steps 3–5 validate against it.
    ref.watch(checklistProvider(fireSafetyTemplateId));
    final size = context.windowSize;
    final title = widget.inspectionId == null ? 'New inspection' : 'Edit ${widget.inspectionId}';

    if (state.loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Step guard: a step can't be opened while an earlier step is invalid.
    final blockedAt = _validator().firstInvalidBefore(_step, state.draft);
    if (blockedAt != null && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _attempted.add(blockedAt));
        context.go(_location(blockedAt.number));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Complete “${blockedAt.title}” first')));
      });
    } else if (blockedAt == null) {
      _redirecting = false;
    }

    final errors = _attempted.contains(_step) ? _validator().step(_step, state.draft) : const <String, String>{};
    final content = WizardStepView(step: _step, wizardKey: _key, errors: errors, onEditStep: _goTo, onSubmit: _submit);
    final savedAt = state.savedAt;
    final savedText = savedAt == null ? null : 'Draft saved on this device · ${DateFormat.Hm().format(savedAt)}';

    final appBar = AppBar(
      leading: IconButton(tooltip: 'Close', onPressed: _close, icon: const Icon(Symbols.close)),
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
        TextButton(onPressed: _saveDraft, child: const Text('Save draft')),
      ],
    );

    final isLast = _step == WizardStep.review;
    final footer = _Footer(
      savedText: size.isTwoPane || isLast ? null : savedText,
      onBack: widget.step > 1 ? _back : null,
      onNext: isLast ? null : _next,
      nextLabel: size.isTwoPane && !isLast ? 'Next: ${WizardStep.fromNumber(widget.step + 1).title}' : 'Next',
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
                child: Semantics(header: true, child: Text(step.title, style: theme.textTheme.titleMedium)),
              ),
              Text(
                'Step ${step.number} of ${WizardScreen.stepCount}',
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
                LinearProgressIndicator(value: value, borderRadius: BorderRadius.circular(4), semanticsLabel: 'Wizard progress'),
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
          'Step ${step.number} of ${WizardScreen.stepCount}',
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Semantics(header: true, child: Text(step.title, style: theme.textTheme.headlineSmall)),
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

  String _hint(WizardStep s) {
    final errors = validator.step(s, draft).length;
    if (errors > 0 && s.number <= draft.lastStep && s != current) {
      return errors == 1 ? '1 field needs attention' : '$errors fields need attention';
    }
    return switch (s) {
      WizardStep.site => draft.siteName.isEmpty ? 'Choose a site' : draft.siteName,
      WizardStep.details => draft.type ?? 'Type, date and time',
      WizardStep.checklist => '${draft.answers.length} of ${validator.checklist.length} answered',
      WizardStep.photos => '${draft.photos.length} photos · ${draft.files.length} files',
      WizardStep.review => 'Check and send',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            for (final s in WizardStep.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  selected: s == current,
                  selectedTileColor: theme.colorScheme.secondaryContainer,
                  shape: const StadiumBorder(),
                  enabled: s.number <= draft.lastStep || s == current,
                  onTap: () => onTap(s.number),
                  leading: _StepDot(step: s, state: _stateOf(s, current, draft, validator)),
                  title: Text(s.title, style: theme.textTheme.titleSmall),
                  subtitle: Text(_hint(s), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
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
      label: 'Wizard steps',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in WizardStep.values) ...[
              InkWell(
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
                        s.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: s == current ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
    final back = OutlinedButton(onPressed: onBack, child: const Text('Back'));
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
