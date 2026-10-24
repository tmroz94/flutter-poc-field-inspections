import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';

export 'filter_sheet.dart';
export 'inspection_detail_screen.dart';
export 'inspection_list_screen.dart';
export 'photo_viewer_screen.dart';

/// P16. Built with the wizard in M2.
class SubmittedScreen extends StatelessWidget {
  const SubmittedScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) =>
      PlaceholderView(title: 'Submitted $id', boards: const ['P16'], links: {'View inspection': Routes.inspection(id)});
}
