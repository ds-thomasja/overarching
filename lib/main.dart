import 'package:flutter/material.dart';
import 'package:lightning_core_ui/lightning_core_ui.dart';

import 'components/device_card/device_card.dart';

void main() {
  runApp(const ComponentPreviewApp());
}

/// Local preview harness for the Overarching components.
///
/// The components are built on the DS Design System, so they need three
/// ancestors to work:
/// - the DS localization delegates (DS widgets resolve their own strings),
/// - [DSTheme], which provides both the legacy `DSThemeData` and the design
///   tokens (`DSTokensData`) that the components read via `DSTokens.of`,
/// - [DSRegion], which provides region-specific number/date formatting.
///
/// [DSTheme] needs a [MediaQuery] ancestor (for the form-factor-dependent
/// tokens), which is why it is installed through [MaterialApp.builder] rather
/// than above [MaterialApp].
class ComponentPreviewApp extends StatelessWidget {
  const ComponentPreviewApp({super.key, this.dark = false});

  /// Renders the gallery with the dark DS theme instead of the light one.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overarching Component Preview',
      debugShowCheckedModeBanner: false,
      // Includes the DS delegate plus the global Material/Cupertino/Widgets
      // delegates that DS widgets rely on (e.g. for DateFormat strings).
      localizationsDelegates: DSCoreUILocalizationDelegates.localizationsDelegates,
      supportedLocales: DSCoreUILocalizationDelegates.supportedLocales,
      builder: (context, child) => DSTheme(
        data: dark ? const DSThemeDataDark() : const DSThemeDataLight(),
        child: DSRegion(
          region: DSRegionDataDE.new,
          child: child!,
        ),
      ),
      home: const ComponentGalleryPage(),
    );
  }
}

/// One entry in the component sidebar: a display name plus the section
/// widget that renders that component's example states.
class _ComponentEntry {
  const _ComponentEntry(this.name, this.section);

  final String name;
  final Widget section;
}

/// The components available in this gallery, ordered alphabetically by name
/// so the sidebar list order stays deterministic as components are added.
final List<_ComponentEntry> _componentEntries = [
  const _ComponentEntry('DeviceCard', _DeviceCardSection()),
]..sort((a, b) => a.name.compareTo(b.name));

/// Shows one component at a time, selected from a sidebar listing every
/// component in the gallery. The first component (alphabetically) is
/// selected by default.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);
    final selected = _componentEntries[_selectedIndex];

    return Scaffold(
      backgroundColor: tokens.background.standard,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ComponentSidebar(
              entries: _componentEntries,
              selectedIndex: _selectedIndex,
              onSelected: (index) => setState(() => _selectedIndex = index),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(tokens.spacing.layout.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overarching Component Gallery',
                      style: tokens.text.headingXl
                          .copyWith(color: tokens.text.standard),
                    ),
                    SizedBox(height: tokens.spacing.layout.l),
                    selected.section,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The left-hand navigation listing every component in the gallery.
class _ComponentSidebar extends StatelessWidget {
  const _ComponentSidebar({
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ComponentEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);

    return SizedBox(
      width: 240,
      child: ColoredBox(
        color: tokens.background.dimmer,
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.layout.s),
          children: [
            for (var i = 0; i < entries.length; i++)
              _ComponentSidebarItem(
                label: entries[i].name,
                selected: i == selectedIndex,
                onPressed: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComponentSidebarItem extends StatelessWidget {
  const _ComponentSidebarItem({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.component.xs,
        vertical: tokens.spacing.component.xxs,
      ),
      child: Material(
        color: selected ? tokens.surfaceSelected.standard : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.border.radius.small),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.border.radius.small),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.component.m,
              vertical: tokens.spacing.component.s,
            ),
            child: Text(
              label,
              style: (selected
                      ? tokens.text.textBaseStrong
                      : tokens.text.textBase)
                  .copyWith(
                color: selected ? tokens.text.interactive : tokens.text.standard,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled block with an optional caption, used to group gallery examples.
class _Section extends StatelessWidget {
  const _Section({required this.title, this.caption, required this.child});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);
    final caption = this.caption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tokens.text.headingBase.copyWith(color: tokens.text.standard),
        ),
        if (caption != null) ...[
          SizedBox(height: tokens.spacing.component.xxs),
          Text(
            caption,
            style: tokens.text.textSm.copyWith(color: tokens.text.subdued),
          ),
        ],
        SizedBox(height: tokens.spacing.component.m),
        const DSDivider.horizontal(),
        SizedBox(height: tokens.spacing.layout.s),
        child,
      ],
    );
  }
}

/// The DeviceCard examples: default, selected, offline/disabled, and
/// loading states, laid out in a wrap so they reflow at any sidebar width.
class _DeviceCardSection extends StatelessWidget {
  const _DeviceCardSection();

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);

    return _Section(
      title: 'DeviceCard',
      caption: 'Default, selected, offline/disabled, and loading states.',
      child: Wrap(
        spacing: tokens.spacing.layout.l,
        runSpacing: tokens.spacing.layout.l,
        children: [
          DeviceCard(
            name: 'Primescan Connect',
            subline: 'SN:865562',
            batteryPercent: 82,
            onTap: () {},
          ),
          DeviceCard(
            name: 'Primescan Connect',
            subline: 'SN:865562',
            batteryPercent: 24,
            selected: true,
            onTap: () {},
          ),
          const DeviceCard(
            name: 'Primescan Connect',
            subline: 'SN:865562',
            batteryPercent: 45,
            status: DeviceCardStatus.offline,
            enabled: false,
          ),
          const DeviceCard(
            name: 'Primescan Connect',
            subline: 'SN:865562',
            isLoading: true,
          ),
        ],
      ),
    );
  }
}
