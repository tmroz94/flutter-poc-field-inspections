import 'package:material_ui/material_ui.dart';

import '../../core/widgets/placeholder_view.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({this.siteId, super.key});

  final String? siteId;

  @override
  Widget build(BuildContext context) => PlaceholderView(title: siteId == null ? 'Map' : 'Map · $siteId', boards: const ['P18']);
}
