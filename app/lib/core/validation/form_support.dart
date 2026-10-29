import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// One validated field: its focus node and a check of its current value.
class FieldCheck {
  const FieldCheck(this.focusNode, this.error);

  final FocusNode focusNode;
  final String? Function() error;
}

/// After a failed submit: move focus to the first invalid field and tell
/// screen-reader users how many fields need attention (WCAG 3.3.1).
void focusFirstInvalid(BuildContext context, List<FieldCheck> fields) {
  final invalid = fields.where((f) => f.error() != null).toList();
  if (invalid.isEmpty) return;
  invalid.first.focusNode.requestFocus();
  final count = invalid.length;
  SemanticsService.sendAnnouncement(
    View.of(context),
    count == 1 ? context.l10n.fieldNeedsAttention(invalid.first.error()!) : context.l10n.fieldsNeedAttention(count),
    Directionality.of(context),
    assertiveness: Assertiveness.assertive,
  );
}

/// Form-level error shown above the submit button (e.g. wrong credentials).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filled button that shows a spinner and ignores taps while [busy], so a
/// form can't be submitted twice.
class BusyButton extends StatelessWidget {
  const BusyButton({required this.label, required this.busy, required this.onPressed, this.outlined = false, super.key});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    // The spinner carries the label: the button's own semantics node takes
    // it as its name ("Signing in…"), so it isn't nameless while busy.
    final child = busy
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: context.l10n.inProgressLabel(label)),
          )
        : Text(label);
    final style = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)));
    final press = busy ? null : onPressed;
    return outlined
        ? OutlinedButton(style: style, onPressed: press, child: child)
        : FilledButton(style: style, onPressed: press, child: child);
  }
}
