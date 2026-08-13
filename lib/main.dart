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

/// One entry in the component sidebar: a display name plus the playground
/// widget that renders that component's live, controls-driven preview.
class _ComponentEntry {
  const _ComponentEntry(this.name, this.playground);

  final String name;
  final Widget playground;
}

/// The components available in this gallery, ordered alphabetically by name
/// so the sidebar list order stays deterministic as components are added.
final List<_ComponentEntry> _componentEntries = [
  const _ComponentEntry('DeviceCard', _DeviceCardPlayground()),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(tokens.spacing.layout.l),
                    child: Text(
                      'Overarching Component Gallery',
                      style: tokens.text.headingXl
                          .copyWith(color: tokens.text.standard),
                    ),
                  ),
                  Expanded(
                    // Each entry's playground owns both the live preview
                    // (center) and the parameter controls (right sidebar) so
                    // the two stay in sync via one shared piece of state.
                    child: selected.playground,
                  ),
                ],
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

/// A titled block with an optional caption, used to introduce a component's
/// live preview area.
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

/// The fixed-width right-hand sidebar holding a component's live parameter
/// controls (text inputs, dropdowns, toggles, ...).
class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);

    return SizedBox(
      width: 280,
      child: ColoredBox(
        color: tokens.background.dimmer,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacing.layout.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controls',
                style: tokens.text.headingBase
                    .copyWith(color: tokens.text.standard),
              ),
              SizedBox(height: tokens.spacing.layout.s),
              for (final child in children) ...[
                child,
                SizedBox(height: tokens.spacing.component.l),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A single labeled control (text input, dropdown, ...) in a [_ControlsPanel].
class _ControlField extends StatelessWidget {
  const _ControlField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSLabel(label: label),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// The three demo states offered by the DeviceCard playground's "State"
/// dropdown, covering the card's non-loading enabled/disabled split plus its
/// loading state.
enum _DeviceCardDemoState { default_, disabled, loading }

extension on _DeviceCardDemoState {
  String get label => switch (this) {
        _DeviceCardDemoState.default_ => 'Default',
        _DeviceCardDemoState.disabled => 'Disabled',
        _DeviceCardDemoState.loading => 'Loading',
      };
}

/// Live, controls-driven preview of [DeviceCard]: a title and subline text
/// input, a state dropdown (default/disabled/loading), and a toggle for
/// whether the battery indicator is shown.
class _DeviceCardPlayground extends StatefulWidget {
  const _DeviceCardPlayground();

  @override
  State<_DeviceCardPlayground> createState() => _DeviceCardPlaygroundState();
}

class _DeviceCardPlaygroundState extends State<_DeviceCardPlayground> {
  late final _titleController =
      TextEditingController(text: 'Primescan Connect');
  late final _sublineController = TextEditingController(text: 'SN:865562');
  _DeviceCardDemoState _state = _DeviceCardDemoState.default_;
  bool _showBattery = true;
  bool _selected = false;

  @override
  void dispose() {
    _titleController.dispose();
    _sublineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);

    final preview = DeviceCard(
      name: _titleController.text,
      subline:
          _sublineController.text.isEmpty ? null : _sublineController.text,
      batteryPercent: _showBattery ? 72 : null,
      selected: _selected,
      enabled: _state != _DeviceCardDemoState.disabled,
      isLoading: _state == _DeviceCardDemoState.loading,
      onTap: () {},
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.spacing.layout.l),
            child: _Section(
              title: 'DeviceCard',
              caption: 'Edit the parameters on the right to update the '
                  'preview live.',
              child: Center(child: preview),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        _ControlsPanel(
          children: [
            _ControlField(
              label: 'Title',
              child: DSInput(
                controller: _titleController,
                onChanged: (_) => setState(() {}),
              ),
            ),
            _ControlField(
              label: 'Subline',
              child: DSInput(
                controller: _sublineController,
                onChanged: (_) => setState(() {}),
              ),
            ),
            _ControlField(
              label: 'State',
              child: DSDropdown<_DeviceCardDemoState>(
                items: [
                  for (final state in _DeviceCardDemoState.values)
                    DSDropdownItem(value: state, title: state.label),
                ],
                value: _state,
                onChanged: (value) =>
                    setState(() => _state = value ?? _state),
              ),
            ),
            DSSwitch(
              label: 'Battery',
              value: _showBattery,
              onChanged: (value) => setState(() => _showBattery = value),
            ),
            DSSwitch(
              label: 'Selected',
              value: _selected,
              onChanged: (value) => setState(() => _selected = value),
            ),
          ],
        ),
      ],
    );
  }
}
