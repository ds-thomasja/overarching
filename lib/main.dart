import 'package:flutter/material.dart';
import 'package:lightning_core_ui/lightning_core_ui.dart';

import 'components/device_card/device_card.dart';
import 'components/device_modal/device_modal.dart';

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
  const _ComponentEntry('DeviceModal', _DeviceModalPlayground()),
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

/// The two structurally different modes a [DeviceModal] can be opened in,
/// matching its two named constructors.
enum _DeviceModalDemoMode { selectDevice, deviceDetails }

extension on _DeviceModalDemoMode {
  String get label => switch (this) {
        _DeviceModalDemoMode.selectDevice => 'Select device (list)',
        _DeviceModalDemoMode.deviceDetails => 'Device details',
      };
}

/// The segment labels of the details-mode segmented control, taken from the
/// Figma mock.
const List<String> _deviceModalSegments = ['DS Core', 'CEREC / Connect'];

/// The two list-mode interaction styles offered by the "Type" dropdown,
/// matching [DeviceModal.selectable]: a plain browsing list, or the
/// selectable-plus-confirm interaction.
enum _DeviceModalListType { default_, selectAndConfirm }

extension on _DeviceModalListType {
  String get label => switch (this) {
        _DeviceModalListType.default_ => 'One click selection',
        _DeviceModalListType.selectAndConfirm => 'Select and confirm',
      };

  bool get selectable => this == _DeviceModalListType.selectAndConfirm;
}

/// Live, controls-driven preview of [DeviceModal].
///
/// A modal is a route rather than an inline widget, so the preview area holds
/// the button that opens it (via the DS `showDSModalDialog`) instead of the
/// component itself. The controls on the right are read when the button is
/// pressed: a DS modal route does not rebuild when the page behind its barrier
/// rebuilds, so a knob flipped *while* the modal is open only takes effect the
/// next time it is opened.
class _DeviceModalPlayground extends StatefulWidget {
  const _DeviceModalPlayground();

  @override
  State<_DeviceModalPlayground> createState() => _DeviceModalPlaygroundState();
}

class _DeviceModalPlaygroundState extends State<_DeviceModalPlayground> {
  late final _nameController = TextEditingController(text: 'Primescan Connect');
  late final _notificationController = TextEditingController(
      text: 'Using the correct sensor helps ensure accurate readings and '
          'prevents errors.');

  _DeviceModalDemoMode _mode = _DeviceModalDemoMode.selectDevice;
  _DeviceModalListType _listType = _DeviceModalListType.selectAndConfirm;
  int _deviceCount = 4;
  bool _showNotification = true;
  bool _showBattery = true;
  bool _showSubline1 = true;
  bool _showSubline2 = true;
  bool _showStatusTag = true;
  bool _showSegmentedControl = true;
  bool _showProgress = true;

  /// The outcome of the last closed modal, echoed under the open button so the
  /// callbacks are observable without a debug console.
  String? _lastOutcome;

  @override
  void dispose() {
    _nameController.dispose();
    _notificationController.dispose();
    super.dispose();
  }

  String? get _notificationMessage {
    if (!_showNotification) return null;
    final message = _notificationController.text;
    return message.isEmpty ? null : message;
  }

  /// The selectable devices of the list mode: full cards, per the Figma
  /// `details=false` variant.
  List<DeviceModalDevice> get _selectableDevices => [
        for (var i = 0; i < _deviceCount; i++)
          DeviceModalDevice(
            name: _nameController.text,
            subline: 'SN:86556${i + 1}',
            batteryPercent: _showBattery ? 88 - i * 7 : null,
            status: _showStatusTag
                ? (i.isEven ? DeviceCardStatus.online : DeviceCardStatus.offline)
                : null,
          ),
      ];

  /// The switchable devices of the details mode: name and subline only, per the
  /// Figma `list` variant.
  List<DeviceModalDevice> get _otherDevices => [
        for (var i = 0; i < _deviceCount; i++)
          const DeviceModalDevice(name: 'Title', subline: 'Description'),
      ];

  Future<void> _openModal() async {
    final outcome = await showDSModalDialog<String>(
      context: context,
      builder: (context, pop) => _DeviceModalDemo(
        mode: _mode,
        selectable: _listType.selectable,
        deviceName: _nameController.text,
        selectableDevices: _selectableDevices,
        otherDevices: _otherDevices,
        notificationMessage: _notificationMessage,
        batteryPercent: _showBattery ? 88 : null,
        subline1: _showSubline1 ? 'Subline-1' : null,
        subline2: _showSubline2 ? 'Subline-2' : null,
        status: _showStatusTag ? DeviceCardStatus.online : null,
        segments: _showSegmentedControl ? _deviceModalSegments : const [],
        progress: _showProgress
            ? const DeviceModalProgress(
                label: 'Loading description...',
                value: 0.4,
              )
            : null,
        pop: pop,
      ),
    );
    if (!mounted) return;
    setState(() => _lastOutcome = outcome ?? 'Dismissed');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);
    final lastOutcome = _lastOutcome;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.spacing.layout.l),
            child: _Section(
              title: 'DeviceModal',
              caption: 'Configure the parameters on the right, then open the '
                  'modal. The controls are read when it opens.',
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DSButton.primary(
                      buttonText: 'Open DeviceModal',
                      onPressed: _openModal,
                    ),
                    if (lastOutcome != null) ...[
                      SizedBox(height: tokens.spacing.component.m),
                      Text(
                        'Last outcome: $lastOutcome',
                        style: tokens.text.textSm
                            .copyWith(color: tokens.text.subdued),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        _ControlsPanel(
          children: [
            _ControlField(
              label: 'Mode',
              child: DSDropdown<_DeviceModalDemoMode>(
                items: [
                  for (final mode in _DeviceModalDemoMode.values)
                    DSDropdownItem(value: mode, title: mode.label),
                ],
                value: _mode,
                onChanged: (value) => setState(() => _mode = value ?? _mode),
              ),
            ),
            if (_mode == _DeviceModalDemoMode.selectDevice)
              _ControlField(
                label: 'Type',
                child: DSDropdown<_DeviceModalListType>(
                  items: [
                    for (final type in _DeviceModalListType.values)
                      DSDropdownItem(value: type, title: type.label),
                  ],
                  value: _listType,
                  onChanged: (value) =>
                      setState(() => _listType = value ?? _listType),
                ),
              ),
            _ControlField(
              label: 'Device name',
              child: DSInput(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
              ),
            ),
            _ControlField(
              label: 'Notification message',
              child: DSInput(
                controller: _notificationController,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
            ),
            _ControlField(
              label: 'Devices in list',
              child: DSDropdown<int>(
                items: [
                  for (final count in [0, 1, 2, 4])
                    DSDropdownItem(value: count, title: '$count'),
                ],
                value: _deviceCount,
                onChanged: (value) =>
                    setState(() => _deviceCount = value ?? _deviceCount),
              ),
            ),
            DSSwitch(
              label: 'Notification',
              value: _showNotification,
              onChanged: (value) => setState(() => _showNotification = value),
            ),
            DSSwitch(
              label: 'Battery',
              value: _showBattery,
              onChanged: (value) => setState(() => _showBattery = value),
            ),
            DSSwitch(
              label: 'Status tag',
              value: _showStatusTag,
              onChanged: (value) => setState(() => _showStatusTag = value),
            ),
            DSSwitch(
              label: 'Subline 1',
              value: _showSubline1,
              onChanged: (value) => setState(() => _showSubline1 = value),
            ),
            DSSwitch(
              label: 'Subline 2',
              value: _showSubline2,
              onChanged: (value) => setState(() => _showSubline2 = value),
            ),
            DSSwitch(
              label: 'Segmented control',
              value: _showSegmentedControl,
              onChanged: (value) =>
                  setState(() => _showSegmentedControl = value),
            ),
            DSSwitch(
              label: 'Progress card',
              value: _showProgress,
              onChanged: (value) => setState(() => _showProgress = value),
            ),
          ],
        ),
      ],
    );
  }
}

/// The [DeviceModal] instance shown by the playground.
///
/// A [StatefulWidget] of its own because the segmented-control selection has to
/// update *inside* the open modal, and a DS modal route does not rebuild when
/// the page behind its barrier does.
class _DeviceModalDemo extends StatefulWidget {
  const _DeviceModalDemo({
    required this.mode,
    required this.selectable,
    required this.deviceName,
    required this.selectableDevices,
    required this.otherDevices,
    required this.notificationMessage,
    required this.batteryPercent,
    required this.subline1,
    required this.subline2,
    required this.status,
    required this.segments,
    required this.progress,
    required this.pop,
  });

  final _DeviceModalDemoMode mode;
  final bool selectable;
  final String deviceName;
  final List<DeviceModalDevice> selectableDevices;
  final List<DeviceModalDevice> otherDevices;
  final String? notificationMessage;
  final int? batteryPercent;
  final String? subline1;
  final String? subline2;
  final DeviceCardStatus? status;
  final List<String> segments;
  final DeviceModalProgress? progress;
  final Pop<String> pop;

  @override
  State<_DeviceModalDemo> createState() => _DeviceModalDemoState();
}

class _DeviceModalDemoState extends State<_DeviceModalDemo> {
  String? _selectedSegment;

  @override
  void initState() {
    super.initState();
    _selectedSegment = widget.segments.firstOrNull;
  }

  @override
  Widget build(BuildContext context) => switch (widget.mode) {
        _DeviceModalDemoMode.selectDevice => DeviceModal.selectDevice(
            devices: widget.selectableDevices,
            selectable: widget.selectable,
            notificationMessage: widget.notificationMessage,
            onClose: widget.pop,
            onConfirm: (index) => widget.pop(
              index == null ? 'Confirmed with no selection' : 'Confirmed #$index',
            ),
          ),
        _DeviceModalDemoMode.deviceDetails => DeviceModal.deviceDetails(
            device: DeviceModalDeviceDetails(
              name: widget.deviceName,
              subline1: widget.subline1,
              subline2: widget.subline2,
              batteryPercent: widget.batteryPercent,
              status: widget.status,
            ),
            otherDevices: widget.otherDevices,
            onOtherDeviceSelected: (index) =>
                widget.pop('Switched to other device #$index'),
            notificationMessage: widget.notificationMessage,
            segments: widget.segments,
            selectedSegment: _selectedSegment,
            onSegmentChanged: (value) =>
                setState(() => _selectedSegment = value),
            progress: widget.progress,
            onClose: widget.pop,
            onSwitchDevice: () => widget.pop('Switch device pressed'),
          ),
      };
}
