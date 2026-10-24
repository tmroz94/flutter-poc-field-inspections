import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// An M3 search bar (56 dp, full radius, leading search icon) built on
/// [TextField]. Material's `SearchBar` exposes only its 24 dp inner field to
/// accessibility services, which fails the 48 dp tap-target guideline; here the
/// whole bar is the text field's semantics node.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.elevation = 0,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const shape = StadiumBorder();
    return Material(
      elevation: elevation,
      color: c.surfaceContainerHigh,
      shape: shape,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Padding(padding: EdgeInsetsDirectional.only(start: 12, end: 4), child: Icon(Symbols.search)),
          suffixIcon: trailing,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          constraints: const BoxConstraints(minHeight: 56),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
