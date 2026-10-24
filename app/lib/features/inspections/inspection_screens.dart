import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/placeholder_view.dart';

class InspectionsScreen extends StatelessWidget {
  const InspectionsScreen({required this.query, super.key});

  /// `status`, `sort`, `q`, `due`: the URL is the source of truth.
  final Map<String, String> query;

  @override
  Widget build(BuildContext context) => PlaceholderView(
    title: 'Inspections',
    boards: const ['P03', 'P04', 'T01', 'D03'],
    links: {
      'Filter and sort': Routes.inspectionsFilter,
      'INS-1042': Routes.inspection('INS-1042'),
      'INS-1038 (overdue)': Routes.inspection('INS-1038'),
      'Unknown INS-9999': Routes.inspection('INS-9999'),
    },
  );
}

class FilterSheet extends StatelessWidget {
  const FilterSheet({required this.query, super.key});

  final Map<String, String> query;

  @override
  Widget build(BuildContext context) => const SizedBox(height: 320, child: Center(child: Text('Filter and sort (P05)')));
}

enum DetailTab { overview, checklist, photos, history }

class InspectionDetailScreen extends StatelessWidget {
  const InspectionDetailScreen({required this.id, required this.tab, super.key});

  final String id;
  final DetailTab tab;

  @override
  Widget build(BuildContext context) => PlaceholderView(
    title: 'Inspection $id · ${tab.name}',
    boards: const ['P06', 'P07', 'T04'],
    links: {
      'Photo p3': Routes.photo(id, 'p3'),
      'Edit': Routes.editInspection(id),
      'Checklist tab': Routes.inspection(id, tab: 'checklist'),
    },
  );
}

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({required this.inspectionId, required this.photoId, super.key});

  final String inspectionId;
  final String photoId;

  @override
  Widget build(BuildContext context) => PlaceholderView(title: 'Photo $photoId', boards: const ['P08']);
}

class SubmittedScreen extends StatelessWidget {
  const SubmittedScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) =>
      PlaceholderView(title: 'Submitted $id', boards: const ['P16'], links: {'View inspection': Routes.inspection(id)});
}
