import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../domain/theme_preference.dart';

/// Presentational "Apariencia" selector: system / light / dark.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ThemePreference selected;
  final ValueChanged<ThemePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.appearanceTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemePreference>(
            key: const Key('theme-selector'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemePreference.system,
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text(S.themeSystem),
              ),
              ButtonSegment(
                value: ThemePreference.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text(S.themeLight),
              ),
              ButtonSegment(
                value: ThemePreference.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text(S.themeDark),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ],
    );
  }
}
