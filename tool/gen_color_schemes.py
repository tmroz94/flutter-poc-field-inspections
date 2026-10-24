"""Generate app/lib/core/theme/color_schemes.dart from the design canvas's m3-tokens.css.

Usage: python tool/gen_color_schemes.py path/to/m3-tokens.css

The CSS has six schemes (light, dark and medium/high contrast of each). Contrast
schemes only list the roles that differ, so they inherit the rest (fixed roles,
shadow, scrim) from the light or dark base.
"""
import pathlib
import re
import sys

ORDER = ['light', 'dark', 'light-medium-contrast', 'light-high-contrast', 'dark-medium-contrast', 'dark-high-contrast']
SKIP = {'background', 'on-background', 'surface-variant'}  # deprecated ColorScheme roles
OUT = pathlib.Path(__file__).resolve().parent.parent / 'app/lib/core/theme/color_schemes.dart'


def camel(name: str) -> str:
    if name == 'inverse-on-surface':
        return 'onInverseSurface'
    head, *rest = name.split('-')
    return head + ''.join(p.title() for p in rest)


def main(css_path: str) -> None:
    css = pathlib.Path(css_path).read_text(encoding='utf-8')
    blocks = {
        m.group(1): dict(re.findall(r'--([a-z-]+):\s*(#[0-9a-f]{6})', m.group(2)))
        for m in re.finditer(r'(?::root, )?\[data-theme="([a-z-]+)"\]\s*\{(.*?)\}', css, re.S)
    }
    lines = [
        "// GENERATED from the design canvas's m3-tokens.css (Material 3 baseline, seed #6750A4).",
        '// Regenerate with tool/gen_color_schemes.py rather than editing by hand.',
        '',
        "import 'package:material_ui/material_ui.dart';",
        '',
        'abstract final class AppColorSchemes {',
    ]
    for name in ORDER:
        dark = name.startswith('dark')
        roles = {**blocks['dark' if dark else 'light'], **blocks[name]}
        lines.append(f'  static const {camel(name)} = ColorScheme(')
        lines.append(f"    brightness: Brightness.{'dark' if dark else 'light'},")
        lines += [f'    {camel(k)}: Color(0xFF{v[1:].upper()}),' for k, v in roles.items() if k not in SKIP]
        lines.append('  );\n')
    lines.append('}')
    OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Wrote {OUT}')


if __name__ == '__main__':
    main(sys.argv[1])
