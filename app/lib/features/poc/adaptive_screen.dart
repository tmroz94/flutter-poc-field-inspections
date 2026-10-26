import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoButton,
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoDialogAction,
        CupertinoNavigationBarBackButton,
        showCupertinoModalPopup;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/capabilities.dart';
import '../../l10n/l10n.dart';

enum _Style { material, cupertino }

/// P23: the `.adaptive` constructors pick Cupertino on iOS and macOS and
/// Material elsewhere. The toggle overrides `ThemeData.platform` for the demo
/// area only, so both looks can be compared on any device.
class AdaptiveWidgetsScreen extends ConsumerStatefulWidget {
  const AdaptiveWidgetsScreen({super.key});

  @override
  ConsumerState<AdaptiveWidgetsScreen> createState() => _AdaptiveWidgetsScreenState();
}

class _AdaptiveWidgetsScreenState extends ConsumerState<AdaptiveWidgetsScreen> {
  late _Style _style = switch (ref.read(capabilitiesProvider).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => _Style.cupertino,
    _ => _Style.material,
  };
  bool _switch = true;
  double _slider = 60;
  DateTime _date = DateTime.now();

  // One range for both pickers (the Material one asserts on a date outside it).
  static final _first = DateTime(2020);
  static final _last = DateTime(2035, 12, 31);

  bool get _cupertino => _style == _Style.cupertino;

  void _report(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(action), duration: const Duration(seconds: 2)));
  }

  Future<void> _showDialog(BuildContext context) async {
    final cupertino = _cupertino;
    // The dialog lives on the root navigator, outside the demo Theme, so it
    // gets the overridden platform again.
    final demoTheme = Theme.of(context);
    // Pop with the dialog's own context: it sits on the root navigator, not the shell branch.
    Widget action(BuildContext dialog, String label, {required bool result, bool destructive = false}) => cupertino
        ? CupertinoDialogAction(isDestructiveAction: destructive, onPressed: () => Navigator.pop(dialog, result), child: Text(label))
        : TextButton(onPressed: () => Navigator.pop(dialog, result), child: Text(label));
    final deleted = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialog) => Theme(
        data: demoTheme,
        child: AlertDialog.adaptive(
          title: const Text('Delete photo?'),
          content: const Text('It is removed from this inspection.'),
          actions: [action(dialog, 'Cancel', result: false), action(dialog, 'Delete', result: true, destructive: true)],
        ),
      ),
    );
    if (mounted) _report(deleted == true ? 'Deleted' : 'Cancelled');
  }

  Future<void> _pickDate(BuildContext context) async {
    if (_cupertino) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (popup) => Container(
          height: 260,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: SafeArea(
            top: false,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              minimumDate: _first,
              maximumDate: _last,
              initialDateTime: _date,
              onDateTimeChanged: (d) => setState(() => _date = d),
            ),
          ),
        ),
      );
      return;
    }
    final initial = _date.isBefore(_first) ? _first : (_date.isAfter(_last) ? _last : _date);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: _first, lastDate: _last);
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant);
    final demoTheme = theme.copyWith(platform: _cupertino ? TargetPlatform.iOS : TargetPlatform.android);

    Widget row(String label, String api, Widget demo) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyLarge),
                    Text(api, style: mono),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                child: Align(alignment: AlignmentDirectional.centerEnd, child: demo),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.adaptiveWidgets)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Style>(
                  segments: const [
                    ButtonSegment(value: _Style.material, label: Text('Material'), icon: Icon(Symbols.android)),
                    ButtonSegment(value: _Style.cupertino, label: Text('Cupertino'), icon: Icon(Symbols.phone_iphone)),
                  ],
                  selected: {_style},
                  onSelectionChanged: (v) => setState(() => _style = v.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'The .adaptive constructors pick Cupertino on iOS and macOS, Material elsewhere. Force either style here to compare.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Everything below sees the overridden platform.
          Theme(
            data: demoTheme,
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row('Switch', 'Switch.adaptive', Switch.adaptive(value: _switch, onChanged: (v) => setState(() => _switch = v))),
                  row(
                    'Slider',
                    'Slider.adaptive',
                    Slider.adaptive(value: _slider, max: 100, onChanged: (v) => setState(() => _slider = v)),
                  ),
                  // Determinate (follows the slider): an endless spinner would keep the
                  // screen animating and burn battery for a static demo.
                  row(
                    'Activity indicator',
                    'CircularProgressIndicator.adaptive',
                    CircularProgressIndicator.adaptive(value: _slider / 100, semanticsLabel: 'Progress'),
                  ),
                  row(
                    'Filled button',
                    'FilledButton / CupertinoButton.filled',
                    _cupertino
                        ? CupertinoButton.filled(onPressed: () => _report('Saved'), child: const Text('Save'))
                        : FilledButton(onPressed: () => _report('Saved'), child: const Text('Save')),
                  ),
                  row(
                    'Back button',
                    'BackButton / CupertinoNavigationBarBackButton',
                    _cupertino
                        ? CupertinoNavigationBarBackButton(previousPageTitle: 'Back', onPressed: () => _report('Back pressed'))
                        : BackButton(onPressed: () => _report('Back pressed')),
                  ),
                  row(
                    'Date picker',
                    'showDatePicker / CupertinoDatePicker',
                    TextButton.icon(
                      onPressed: () => _pickDate(context),
                      icon: const Icon(Symbols.calendar_month),
                      label: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alert dialog', style: theme.textTheme.bodyLarge),
                        Text('showAdaptiveDialog + AlertDialog.adaptive', style: mono),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showDialog(context),
                          icon: const Icon(Symbols.open_in_new),
                          label: const Text('Show dialog'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
