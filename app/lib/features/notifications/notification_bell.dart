import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../l10n/l10n.dart';
import '../inspections/inspections_controller.dart';

/// App bar bell with the unread count badge (P02, P03, D02).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0;
    return IconButton(
      tooltip: context.l10n.notificationsUnread(unread),
      onPressed: () => context.push(Routes.notifications),
      icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Symbols.notifications)),
    );
  }
}
