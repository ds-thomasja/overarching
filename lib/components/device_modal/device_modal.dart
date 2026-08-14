import 'package:flutter/material.dart';
import 'package:lightning_core_ui/lightning_core_ui.dart';

import '../device_card/device_card.dart';

/// The glyph separating the metadata items in [DeviceModal]'s details info row.
///
/// Same glyph [DeviceCard] uses between its subline and battery indicator.
const String _dividerGlyph = '·';

/// The side length of the details-mode image slot, in logical pixels.
///
/// This is the one visual value in [DeviceModalThemeData] that is *not* derived
/// from a design token: the Figma node specifies a 240x240 slot and DS v51.0.0
/// exposes no matching size token (`image.size.card` is 128/64, intended for
/// card thumbnails). It is kept here, next to the tokens, so it stays a single
/// point of change if such a token is introduced.
const double _detailsImageSize = 240;

/// Default copy for [DeviceModal.selectDevice]'s selection-validation
/// notification, shown when Confirm is pressed with no device selected.
const String _defaultSelectionRequiredMessage =
    'Please select a device before continue';

/// One device rendered as a [DeviceCard] inside a [DeviceModal].
///
/// Used for both device lists a [DeviceModal] can show:
/// - the selectable devices of [DeviceModal.selectDevice], which typically
///   carry the full set of fields, and
/// - the other, switchable devices of [DeviceModal.deviceDetails], which in the
///   Figma node carry a name and subline only.
///
/// Every field maps 1:1 onto the [DeviceCard] parameter of the same name, so
/// the presence or absence of data (rather than a presentation flag) decides
/// what the card shows.
class DeviceModalDevice {
  /// Creates a device entry.
  const DeviceModalDevice({
    required this.name,
    this.subline,
    this.thumbnail,
    this.batteryPercent,
    this.lowBatteryThreshold = 30,
    this.status,
    this.enabled = true,
  });

  /// Forwarded to [DeviceCard.name].
  final String name;

  /// Forwarded to [DeviceCard.subline].
  final String? subline;

  /// Forwarded to [DeviceCard.thumbnail].
  final Widget? thumbnail;

  /// Forwarded to [DeviceCard.batteryPercent]; the indicator is hidden when
  /// null.
  final int? batteryPercent;

  /// Forwarded to [DeviceCard.lowBatteryThreshold].
  final int lowBatteryThreshold;

  /// Forwarded to [DeviceCard.status]; the status tag is hidden when null.
  ///
  /// Deliberately defaults to `null` rather than to [DeviceCard]'s own
  /// `DeviceCardStatus.online` default: this class describes *data*, and a
  /// device whose connectivity is not stated should not claim to be online.
  /// It also makes the name/subline-only card of the Figma details mode the
  /// zero-configuration case.
  final DeviceCardStatus? status;

  /// Forwarded to [DeviceCard.enabled].
  final bool enabled;
}

/// The single, focused device rendered by [DeviceModal.deviceDetails].
///
/// The Figma node's `subline1`, `subline2` and `battery` booleans are
/// translated into nullable data fields here, the same way [DeviceCard]
/// translated its own subline/battery toggles: presence of the data drives
/// visibility.
class DeviceModalDeviceDetails {
  /// Creates the focused device of a details modal.
  const DeviceModalDeviceDetails({
    required this.name,
    this.subline1,
    this.subline2,
    this.batteryPercent,
    this.lowBatteryThreshold = 30,
    this.status,
    this.image,
  });

  /// The device name. Doubles as the modal title in details mode.
  final String name;

  /// First metadata item of the info row. Hidden when null.
  final String? subline1;

  /// Second metadata item of the info row. Hidden when null.
  final String? subline2;

  /// Battery level 0-100, rendered by the DS [DSBatteryIndicator]. The
  /// indicator is hidden when null.
  final int? batteryPercent;

  /// At or below this level the battery indicator switches to its critical
  /// color. Forwarded to [DSBatteryIndicator.lowLevelThreshold]; the default of
  /// 30 mirrors that widget's own default.
  final int lowBatteryThreshold;

  /// Connectivity status, rendered as a right-aligned status tag in the info
  /// row. Hidden when null.
  final DeviceCardStatus? status;

  /// The widget filling the [_detailsImageSize] square image slot.
  ///
  /// Falls back to a plain placeholder box when omitted, matching
  /// [DeviceCard]'s own thumbnail fallback.
  final Widget? image;

  /// Whether the info row would render anything at all.
  bool get _hasInfo =>
      subline1 != null ||
      subline2 != null ||
      batteryPercent != null ||
      status != null;
}

/// An ongoing operation rendered by [DeviceModal.deviceDetails] as a bordered
/// card containing a [DSProgressBar] and a label.
///
/// Replaces the Figma node's `loading` boolean: the caller supplies real
/// progress data instead of toggling canned copy.
class DeviceModalProgress {
  /// Creates a progress card description.
  ///
  /// A null [value] yields an indeterminate (animated) bar; otherwise [value]
  /// is forwarded verbatim to [DSProgressBar.value] and must be between 0.0
  /// and 1.0.
  const DeviceModalProgress({required this.label, this.value});

  /// The label rendered below the bar, e.g. "Loading description...".
  final String label;

  /// Progress between 0.0 and 1.0, or null for indeterminate progress.
  final double? value;
}

/// A modal dialog for picking a device from a list, or for inspecting one
/// device and switching away from it.
///
/// Shown through `showDSModalDialog`, which supplies the dimmed barrier
/// (`background/dimmer` = black at 32%, exactly the Figma value), the centered
/// alignment, the route and the inherited themes.
///
/// The surface itself is [_DeviceModalSurface] — a token-for-token rebuild of
/// [DSModalDialog]'s chrome (surface with `border/radius/large` and
/// `spacing/layout/m` padding, header row with title and tertiary close
/// icon-button, scrollable body with the DS hover-visible scrollbar,
/// right-aligned button toolbar). It exists only because [DSModalDialog]
/// hard-codes a 24px inset above and below its body that the Figma node does
/// not have; see [_DeviceModalSurface] for the full reasoning and the trade-off
/// this carries. This widget itself supplies the device-specific body content,
/// plus the footer button label and callback.
///
/// It is a plain widget, not a route: show it the DS way, with
/// [showDSModalDialog], so it inherits the DS barrier, alignment and
/// pointer-interceptor behavior:
///
/// ```dart
/// showDSModalDialog<int?>(
///   context: context,
///   builder: (context, pop) => DeviceModal.selectDevice(
///     devices: devices,
///     onClose: pop,
///     onConfirm: pop,
///   ),
/// );
/// ```
///
/// ## The two modes
///
/// The Figma node's `details` boolean selects between two structurally
/// different content shapes, which take genuinely different data. They are
/// therefore exposed as two named constructors rather than as a flag:
///
/// - [DeviceModal.selectDevice] — a list of selectable devices plus a primary
///   "Confirm" button. Rendered as one [DeviceCard] per device.
/// - [DeviceModal.deviceDetails] — one focused device (metadata row, image),
///   an optional segmented control, an optional progress card, an optional
///   list of other devices, plus a secondary "Switch device" button.
///
/// The remaining Figma booleans map onto optional data instead of flags:
/// `notification` onto [notificationMessage], `loading` onto [progress],
/// `segmentedControl` onto [segments], `battery`/`subline1`/`subline2` onto the
/// nullable fields of [DeviceModalDeviceDetails], `list` onto a possibly-empty
/// `otherDevices`, and `buttons` onto a nullable footer callback. `scrollbar`
/// has no equivalent at all: [DSModalDialog] scrolls its body and shows a real
/// DS scrollbar, so there is nothing to toggle.
///
/// ## Relationship to the Figma source of truth
///
/// The design lives in Figma "Equipment-Components", node `5098:5219`.
///
/// - Header-to-body and body-to-toolbar gaps: reproduced exactly, per mode —
///   0 above the body in details mode, 16 in list mode, 16 below it in both. This
///   is the one place where Figma deliberately wins over the DS chrome, at the
///   cost of rebuilding the surface; see [_DeviceModalSurface].
/// - Width: Figma shows a fixed 486. DS modal widths are responsive; 486 is
///   exactly `modal.width.responsiveLayoutXl.small`, i.e. what
///   [DSModalDialogVariant.small] resolves to at the extra-large form factor.
///   [variant] therefore defaults to [DSModalDialogVariant.small], reproducing
///   the mock at that form factor and narrowing on smaller ones (366/384/328).
/// - Elevation: the Figma node mentions an elevation shadow. None is applied,
///   matching [DSModalDialog], which decorates its surface with a color and a
///   radius only. Keeping DS parity here means the *only* intended visual
///   difference from the previous [DSModalDialog]-based build is the two gaps
///   above.
///
/// Everything the modal *content* controls does follow the Figma node, and the
/// device rows are the project's real [DeviceCard] rather than a re-render of
/// it.
class DeviceModal extends StatefulWidget {
  DeviceModal._({
    super.key,
    required this.title,
    required this.details,
    required this.devices,
    required this.selectable,
    required this.onClose,
    required this.onConfirm,
    required this.onOtherDeviceSelected,
    required this.onSwitchDevice,
    required this.footerButtonLabel,
    required this.initiallySelectedIndex,
    required this.selectionRequiredMessage,
    required this.notificationMessage,
    required this.notificationType,
    required this.onNotificationClose,
    required this.segments,
    required this.selectedSegment,
    required this.onSegmentChanged,
    required this.progress,
    required this.variant,
  }) : assert(
          segments.length == segments.toSet().length,
          'segments must be unique: the label doubles as the segment value.',
        );

  /// A modal listing selectable devices, with a primary confirm button.
  ///
  /// Corresponds to the Figma `details=false` variant ("Select device").
  ///
  /// The pending selection is held by this widget: taps move the highlight
  /// between the [devices] cards, and only [onConfirm] commits it. That is a
  /// deliberate departure from the caller-driven `selected` of [DeviceCard]
  /// (and of DS widgets like `DSCheckbox`): a confirm-style modal is a
  /// self-contained interaction, and hoisting a selection that is discarded on
  /// close into every caller buys nothing. Seed it with
  /// [initiallySelectedIndex], which is read once, on first build.
  ///
  /// Set [selectable] to `false` for a "one-click" list: there is no footer
  /// button at all — tapping any card calls [onConfirm] immediately, with
  /// that card's index, instead of moving a highlight. [confirmLabel] and
  /// [selectionRequiredMessage] are then unused.
  ///
  /// When [selectable] is `true` (the default), tapping a card only moves the
  /// pending highlight; Confirm is gated on a selection existing, and pressing
  /// it with none made shows [selectionRequiredMessage] as an informational
  /// notification instead of calling [onConfirm], replacing
  /// [notificationMessage] until a card is selected or the notification is
  /// dismissed.
  DeviceModal.selectDevice({
    Key? key,
    required List<DeviceModalDevice> devices,
    required VoidCallback onClose,
    ValueChanged<int?>? onConfirm,
    int? initiallySelectedIndex,
    String title = 'Select device',
    String confirmLabel = 'Confirm',
    bool selectable = true,
    String selectionRequiredMessage = _defaultSelectionRequiredMessage,
    String? notificationMessage,
    DSNotificationType notificationType = DSNotificationType.information,
    VoidCallback? onNotificationClose,
    DSModalDialogVariant variant = DSModalDialogVariant.small,
  }) : this._(
          key: key,
          title: title,
          details: null,
          devices: devices,
          selectable: selectable,
          onClose: onClose,
          onConfirm: onConfirm,
          onOtherDeviceSelected: null,
          onSwitchDevice: null,
          footerButtonLabel: confirmLabel,
          initiallySelectedIndex: initiallySelectedIndex,
          selectionRequiredMessage: selectionRequiredMessage,
          notificationMessage: notificationMessage,
          notificationType: notificationType,
          onNotificationClose: onNotificationClose,
          segments: const [],
          selectedSegment: null,
          onSegmentChanged: null,
          progress: null,
          variant: variant,
        );

  /// A modal describing one [device], with a secondary switch button.
  ///
  /// Corresponds to the Figma `details=true` variant. The modal title is the
  /// device's own [DeviceModalDeviceDetails.name].
  ///
  /// [otherDevices] are the devices the user could switch to, rendered as
  /// [DeviceCard]s below the rest of the content; they are only tappable when
  /// [onOtherDeviceSelected] is given.
  DeviceModal.deviceDetails({
    Key? key,
    required DeviceModalDeviceDetails device,
    required VoidCallback onClose,
    List<DeviceModalDevice> otherDevices = const [],
    ValueChanged<int>? onOtherDeviceSelected,
    VoidCallback? onSwitchDevice,
    String switchDeviceLabel = 'Switch device',
    List<String> segments = const [],
    String? selectedSegment,
    ValueChanged<String?>? onSegmentChanged,
    DeviceModalProgress? progress,
    String? notificationMessage,
    DSNotificationType notificationType = DSNotificationType.information,
    VoidCallback? onNotificationClose,
    DSModalDialogVariant variant = DSModalDialogVariant.small,
  }) : this._(
          key: key,
          title: device.name,
          details: device,
          devices: otherDevices,
          selectable: true,
          onClose: onClose,
          onConfirm: null,
          onOtherDeviceSelected: onOtherDeviceSelected,
          onSwitchDevice: onSwitchDevice,
          footerButtonLabel: switchDeviceLabel,
          initiallySelectedIndex: null,
          // Irrelevant here: details mode has no selection-gated Confirm.
          selectionRequiredMessage: _defaultSelectionRequiredMessage,
          notificationMessage: notificationMessage,
          notificationType: notificationType,
          onNotificationClose: onNotificationClose,
          segments: segments,
          selectedSegment: selectedSegment,
          onSegmentChanged: onSegmentChanged,
          progress: progress,
          variant: variant,
        );

  /// The modal title. In details mode this is the focused device's name.
  final String title;

  /// The focused device in details mode; `null` selects the list mode.
  final DeviceModalDeviceDetails? details;

  /// The devices rendered as [DeviceCard]s: the selectable ones in list mode,
  /// the switchable ones in details mode.
  ///
  /// In details mode, hidden while [progress] is non-null — see
  /// [_DeviceModalState._buildDetailsBody].
  final List<DeviceModalDevice> devices;

  /// Whether the [devices] cards respond to taps and show the pending
  /// selection highlight in list mode. Ignored in details mode, where
  /// interactivity is instead governed by [onOtherDeviceSelected].
  final bool selectable;

  /// Called when the header close button is pressed.
  ///
  /// Forwarded to [DSModalDialog.onClose], so actually dismissing the modal is
  /// the caller's responsibility, and passing [hideDialogCloseButton] hides the
  /// close button altogether.
  final VoidCallback onClose;

  /// Called with a device index in list mode: either immediately when a card
  /// is tapped and [selectable] is `false` ("one-click" list, which has no
  /// footer button — see [DeviceModal.selectDevice]), or when the primary
  /// confirm button is pressed with a selection made and [selectable] is
  /// `true`. The button itself is disabled when [onConfirm] is null.
  ///
  /// When [selectable] is `true` and no device is selected, pressing Confirm
  /// does *not* call this — it shows [selectionRequiredMessage] instead.
  final ValueChanged<int?>? onConfirm;

  /// Called with the index into [devices] when one of the details-mode
  /// switchable device cards is tapped; the cards are non-interactive when
  /// null.
  final ValueChanged<int>? onOtherDeviceSelected;

  /// Called when the secondary switch button is pressed in details mode; the
  /// button is disabled when null.
  final VoidCallback? onSwitchDevice;

  /// The label of the single footer button of the active mode.
  ///
  /// Exposed per mode as `confirmLabel` / `switchDeviceLabel` so the strings
  /// can come from the host application's own localizations; the defaults are
  /// the English copy of the Figma node.
  final String footerButtonLabel;

  /// The initially selected index into [devices] in list mode.
  ///
  /// Read once, on first build. Later changes are ignored, since the selection
  /// is owned by this widget from that point on.
  final int? initiallySelectedIndex;

  /// The selection-validation notification shown when [selectable] is `true`
  /// and Confirm is pressed with no device selected.
  ///
  /// Exposed the same way [footerButtonLabel] is, so the host application can
  /// supply its own localization; the default is the English copy the
  /// behavior was specified with. Irrelevant in details mode.
  final String selectionRequiredMessage;

  /// The message of the inline notification banner. The banner is hidden when
  /// null.
  ///
  /// While the [selectionRequiredMessage] validation notification is showing,
  /// it takes this banner's place; this message returns once a device is
  /// selected or that notification is dismissed.
  final String? notificationMessage;

  /// The type (and therefore the color and icon) of the inline notification.
  ///
  /// The Figma node shows the information variant; other types are accepted so
  /// the same modal can surface a warning or a failure.
  final DSNotificationType notificationType;

  /// Called when the notification's own close button is pressed. The
  /// notification renders no close button when null.
  final VoidCallback? onNotificationClose;

  /// The labels of the details-mode segmented control. Empty hides it.
  ///
  /// Each label doubles as the segment value, so labels must be unique. The DS
  /// segmented control is meant for two options; use a `DSDropdown` for more.
  final List<String> segments;

  /// The currently selected entry of [segments], or null for no selection.
  final String? selectedSegment;

  /// Called with the newly selected segment label, or `null` when the already
  /// selected segment is tapped again (DS deselection semantics).
  final ValueChanged<String?>? onSegmentChanged;

  /// The details-mode progress card. Hidden when null.
  final DeviceModalProgress? progress;

  /// The DS modal size variant.
  ///
  /// Defaults to [DSModalDialogVariant.small], which is the variant whose
  /// width matches the Figma node's 486 at the extra-large form factor.
  final DSModalDialogVariant variant;

  @override
  State<DeviceModal> createState() => _DeviceModalState();
}

class _DeviceModalState extends State<DeviceModal> {
  /// The pending selection in list mode: an index into
  /// [DeviceModal.devices], or null for "nothing selected".
  int? _selectedIndex;

  /// Whether Confirm was pressed in selectable list mode with no selection.
  ///
  /// While true, [_buildNotification] shows [DeviceModal.selectionRequiredMessage]
  /// in place of [DeviceModal.notificationMessage]. Cleared by selecting a
  /// device or dismissing that notification.
  bool _selectionRequired = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initiallySelectedIndex;
  }

  @override
  void didUpdateWidget(DeviceModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop a selection that the shortened list no longer contains, so a stale
    // index can never be handed to onConfirm.
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.devices.length) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DeviceModalThemeData(DSTokens.of(context));
    final details = widget.details;

    return _DeviceModalSurface(
      theme: theme,
      variant: widget.variant,
      title: widget.title,
      onClose: widget.onClose,
      // The one difference between the two modes' chrome, and the whole reason
      // this surface is hand-composed: see [_DeviceModalSurface].
      bodyTopGap: details == null
          ? theme.selectBodyTopGap
          : theme.detailsBodyTopGap,
      body: details == null
          ? _buildSelectBody(theme)
          : _buildDetailsBody(theme, details),
      buttons: [
        // "One-click" list mode (selectable false) has no footer button:
        // tapping a card already acts, via onConfirm — see _buildSelectBody.
        if (details == null && widget.selectable)
          DSButton.primary(
            buttonText: widget.footerButtonLabel,
            onPressed: widget.onConfirm == null
                ? null
                : () {
                    if (_selectedIndex == null) {
                      setState(() => _selectionRequired = true);
                    } else {
                      widget.onConfirm!(_selectedIndex);
                    }
                  },
          )
        else if (details != null)
          DSButton.secondary(
            buttonText: widget.footerButtonLabel,
            onPressed: widget.onSwitchDevice,
          ),
      ],
    );
  }

  /// The `details=false` body: the optional notification followed by one
  /// [DeviceCard] per device.
  ///
  /// When [DeviceModal.selectable] is `true`, tapping a card only moves the
  /// pending highlight. When it is `false` ("one-click" list), tapping a card
  /// calls [DeviceModal.onConfirm] immediately with its index instead.
  Widget _buildSelectBody(DeviceModalThemeData theme) => _Stack(
        defaultSpacing: theme.blockSpacing,
        children: [
          _Block.orNull(_buildNotification()),
          for (var i = 0; i < widget.devices.length; i++)
            _Block.orNull(
              _buildDeviceCard(
                widget.devices[i],
                selected: widget.selectable && i == _selectedIndex,
                onTap: widget.selectable
                    ? () => setState(() {
                          _selectedIndex = i;
                          _selectionRequired = false;
                        })
                    : widget.onConfirm == null
                        ? null
                        : () => widget.onConfirm!(i),
              ),
            ),
        ],
      );

  /// The `details=true` body: the focused device's info row and image, then the
  /// optional segmented control, notification, progress card and switchable
  /// device list.
  ///
  /// [progress] and the switchable [widget.devices] list are alternate states
  /// of the same area — loading versus loaded — not simultaneous blocks: when
  /// [progress] is shown, the device list is suppressed regardless of what
  /// [widget.devices] holds, so a caller driving both from the same "is
  /// loading" flag never has to remember to also clear the list itself.
  ///
  /// Most gaps are the default `spacing/component/xs` (8), but four are
  /// widened to `spacing/component/m` (16), per direct confirmation against
  /// the Figma node: between the info row and the image, below the image,
  /// and below the notification and segmented control whenever they're
  /// shown — regardless of which block follows.
  Widget _buildDetailsBody(
    DeviceModalThemeData theme,
    DeviceModalDeviceDetails details,
  ) =>
      _Stack(
        defaultSpacing: theme.blockSpacing,
        children: [
          if (details._hasInfo)
            _Block(
              _DetailsInfoRow(details: details, theme: theme),
              spacingAfter: theme.wideBlockSpacing,
            ),
          _Block(
            _DetailsImage(image: details.image, theme: theme),
            spacingAfter: theme.wideBlockSpacing,
          ),
          if (widget.segments.isNotEmpty)
            _Block(
              DSSegmentedControl.withTexts(
                // Full width, per the Figma node.
                stretch: true,
                selectedValue: widget.selectedSegment,
                onChanged: widget.onSegmentChanged,
                items: [
                  for (final segment in widget.segments)
                    DSSegmentedControlItemWithText(
                      value: segment,
                      text: segment,
                      // A segmented control with no handler would silently
                      // swallow taps; disabling the segments says so.
                      enabled: widget.onSegmentChanged != null,
                    ),
                ],
              ),
              spacingAfter: theme.wideBlockSpacing,
            ),
          _Block.orNull(
            _buildNotification(),
            spacingAfter: theme.wideBlockSpacing,
          ),
          _Block.orNull(_buildProgressCard(theme)),
          if (widget.progress == null)
            for (var i = 0; i < widget.devices.length; i++)
              _Block.orNull(
                _buildDeviceCard(
                  widget.devices[i],
                  selected: false,
                  onTap: widget.onOtherDeviceSelected == null
                      ? null
                      : () => widget.onOtherDeviceSelected!(i),
                ),
              ),
        ],
      );

  /// The DS inline notification banner shared by both modes.
  ///
  /// This is the real DS component: the info-subdued background, the
  /// info-colored leading border and the Info-Circle icon of the Figma node all
  /// come from [DSInlineNotification] itself.
  ///
  /// While [_selectionRequired] is set, this shows
  /// [DeviceModal.selectionRequiredMessage] as an informational notice, with
  /// its own close handler, in place of [DeviceModal.notificationMessage].
  ///
  /// Deliberately [DSNotificationType.information] rather than `.warning`:
  /// missing a selection is not a problem with existing state, just a
  /// pending step, so the less alarming type reads better here.
  Widget? _buildNotification() {
    if (_selectionRequired) {
      return DSInlineNotification(
        message: widget.selectionRequiredMessage,
        notificationType: DSNotificationType.information,
        onClose: () => setState(() => _selectionRequired = false),
      );
    }
    final message = widget.notificationMessage;
    return message == null
        ? null
        : DSInlineNotification(
            message: message,
            notificationType: widget.notificationType,
            onClose: widget.onNotificationClose,
          );
  }

  Widget? _buildProgressCard(DeviceModalThemeData theme) {
    final progress = widget.progress;
    return progress == null
        ? null
        : _ProgressCard(progress: progress, theme: theme);
  }

  /// Builds a device row with the project's real [DeviceCard].
  ///
  /// The card is stretched to the modal's content width rather than pinned to
  /// [DeviceCard]'s own 438 default. At the Figma modal width (486 minus two
  /// 24 paddings) those are the same number, but stretching also keeps the
  /// rows intact once the DS modal narrows on smaller form factors, or once
  /// the body's scrollbar gutter takes width away.
  Widget _buildDeviceCard(
    DeviceModalDevice device, {
    required bool selected,
    required VoidCallback? onTap,
  }) =>
      DeviceCard(
        width: double.infinity,
        name: device.name,
        subline: device.subline,
        thumbnail: device.thumbnail,
        batteryPercent: device.batteryPercent,
        lowBatteryThreshold: device.lowBatteryThreshold,
        status: device.status,
        enabled: device.enabled,
        selected: selected,
        onTap: device.enabled ? onTap : null,
      );
}

/// Design tokens for [DeviceModal], covering both the modal chrome rebuilt by
/// [_DeviceModalSurface] and the mode-specific content.
///
/// Every value is derived from [DSTokensData], mirroring the DS-internal
/// `DSModalDialogThemeData` token for token so the surface stays visually
/// identical to [DSModalDialog]. It follows the same token-derivation
/// convention as [DeviceCardThemeData] and the DS package's own internal
/// `*ThemeData` classes: a plain class whose fields are computed once from
/// [DSTokensData] in the constructor.
class DeviceModalThemeData {
  /// Derives the theme from the ambient design tokens.
  DeviceModalThemeData(DSTokensData d)
      : surfaceBackground = d.surface.standard,
        surfaceBorderRadius = BorderRadius.circular(d.border.radius.large),
        surfaceHorizontalPadding =
            EdgeInsets.symmetric(horizontal: d.spacing.layout.m),
        surfaceVerticalPadding =
            EdgeInsets.symmetric(vertical: d.spacing.layout.m),
        screenVerticalPadding = 2 * d.spacing.layout.m,
        titleTextStyle = d.text.heading2xl,
        titlePadding = EdgeInsets.only(
          top: d.spacing.component.xxs,
          right: d.spacing.layout.m,
          bottom: d.spacing.component.xxs,
        ),
        toolbarSpacing = d.spacing.component.xs,
        selectBodyTopGap = d.spacing.component.m,
        detailsBodyTopGap = 0,
        bodyBottomGap = d.spacing.component.m,
        smallVariantWidth = DSResponsiveProperty.resolveTo(
          s: d.modal.width.responsiveLayoutS.small,
          m: d.modal.width.responsiveLayoutM.small,
          l: d.modal.width.responsiveLayoutL.small,
          xl: d.modal.width.responsiveLayoutXl.small,
        ),
        mediumVariantWidth = DSResponsiveProperty.resolveTo(
          s: d.modal.width.responsiveLayoutS.medium,
          m: d.modal.width.responsiveLayoutM.medium,
          l: d.modal.width.responsiveLayoutL.medium,
          xl: d.modal.width.responsiveLayoutXl.medium,
        ),
        largeVariantWidth = DSResponsiveProperty.resolveTo(
          s: d.modal.width.responsiveLayoutS.large,
          m: d.modal.width.responsiveLayoutM.large,
          l: d.modal.width.responsiveLayoutL.large,
          xl: d.modal.width.responsiveLayoutXl.large,
        ),
        blockSpacing = d.spacing.component.xs,
        wideBlockSpacing = d.spacing.component.m,
        dividerWidth = d.spacing.component.m,
        infoTextStyle = d.text.textBase.copyWith(color: d.text.standard),
        imageSize = _detailsImageSize,
        imageBorderRadius = BorderRadius.circular(d.border.radius.small),
        imagePlaceholderColor = d.surface.subdued,
        progressCardPadding = EdgeInsets.all(d.spacing.component.l),
        progressCardBorderRadius =
            BorderRadius.circular(d.border.radius.standard),
        progressCardBorder = Border.all(
          color: d.border.standard,
          width: d.border.width.standard,
        ),
        progressCardBackground = d.surface.standard,
        progressCardSpacing = d.spacing.component.s,
        progressLabelTextStyle =
            d.text.textSmStrong.copyWith(color: d.text.standard);

  /// Fill of the modal surface.
  final Color surfaceBackground;

  /// Corner radius of the modal surface (`border/radius/large`, 16).
  final BorderRadius surfaceBorderRadius;

  /// The surface's left/right padding (`spacing/layout/m`, 24), applied
  /// separately from [surfaceVerticalPadding] because the header, body and
  /// toolbar each receive it individually — exactly as [DSModalDialog] does.
  final EdgeInsets surfaceHorizontalPadding;

  /// The surface's top/bottom padding (`spacing/layout/m`, 24).
  final EdgeInsets surfaceVerticalPadding;

  /// Total vertical space kept free between the surface and the screen edges.
  final double screenVerticalPadding;

  /// Text style of the modal title (`heading2xl`, 24/32).
  final TextStyle titleTextStyle;

  /// Padding around the title inside the header row.
  ///
  /// The `spacing/component/xxs` (4) top and bottom turn the title's 32px line
  /// box into a 40px header row, matching the 40x40 close icon-button.
  final EdgeInsets titlePadding;

  /// Gap between the footer toolbar's buttons.
  final double toolbarSpacing;

  /// Gap between the header and the body in list mode:
  /// `spacing/component/m` (16), per direct confirmation against the Figma
  /// node's `details=false` variant. Deliberately not applied in details
  /// mode; see [detailsBodyTopGap].
  final double selectBodyTopGap;

  /// Gap between the header and the body in details mode.
  ///
  /// Deliberately zero, and therefore the one visual value here that is *not*
  /// token-derived: the Figma `details=true` variant places no `LayoutSpacing`
  /// component at all between the header and the scroll view, so there is no
  /// spacing token to reference.
  final double detailsBodyTopGap;

  /// Gap between the body and the footer toolbar, in both modes:
  /// `spacing/component/m` (16), per direct confirmation against the Figma
  /// node.
  ///
  /// Applied only when a footer button is actually present — the "one-click"
  /// list mode has none (see [DeviceModal.selectDevice]), and then the
  /// surface's own [surfaceVerticalPadding] is the only space left below the
  /// body; see [_DeviceModalSurface].
  final double bodyBottomGap;

  /// Width of the surface for [DSModalDialogVariant.small], per form factor.
  final DSResponsiveProperty<double> smallVariantWidth;

  /// Width of the surface for [DSModalDialogVariant.medium], per form factor.
  final DSResponsiveProperty<double> mediumVariantWidth;

  /// Width of the surface for [DSModalDialogVariant.large], per form factor.
  final DSResponsiveProperty<double> largeVariantWidth;

  /// The responsive surface width for the given [variant].
  DSResponsiveProperty<double> widthFor(DSModalDialogVariant variant) =>
      switch (variant) {
        DSModalDialogVariant.small => smallVariantWidth,
        DSModalDialogVariant.medium => mediumVariantWidth,
        DSModalDialogVariant.large => largeVariantWidth,
      };

  /// The default gap between two stacked content blocks, and between two
  /// device cards: `spacing/component/xs` (8).
  final double blockSpacing;

  /// The wider gap used after specific details-mode blocks, per direct
  /// confirmation against the Figma node: between the info row and the
  /// image, below the image itself, and below the notification and
  /// segmented control when they are shown. `spacing/component/m` (16).
  final double wideBlockSpacing;

  /// Total width of the "·" divider box in the details info row. The glyph is
  /// centered inside it.
  ///
  /// Same treatment (and same token) [DeviceCard] applies to its own divider:
  /// a fixed box rather than padding around the glyph.
  final double dividerWidth;

  /// Text style, including color, of the details info row items.
  final TextStyle infoTextStyle;

  /// Side length of the square details image slot.
  ///
  /// See [_detailsImageSize] for why this is not token-derived.
  final double imageSize;

  /// Corner radius of the details image slot.
  ///
  /// Deliberately `border/radius/small`, per the Figma node — the same smaller
  /// radius [DeviceCard] gives its thumbnail.
  final BorderRadius imageBorderRadius;

  /// Fill of the details image slot when no image widget is supplied.
  ///
  /// Matches [DeviceCard]'s thumbnail fallback rather than the arguably more
  /// specific `image_background/standard` token, so an image-less device looks
  /// the same in the list and in the details view.
  final Color imagePlaceholderColor;

  /// Inner padding of the progress card: `spacing/component/l` (24), per the
  /// Figma node.
  final EdgeInsets progressCardPadding;

  /// Corner radius of the progress card.
  ///
  /// The Figma node does not specify one; `border/radius/standard` is the
  /// radius DS gives its own cards.
  final BorderRadius progressCardBorderRadius;

  /// The progress card's 1px `border/standard` outline.
  final Border progressCardBorder;

  /// Fill of the progress card.
  final Color progressCardBackground;

  /// Gap between the progress bar and its label: `spacing/component/s` (12),
  /// per the Figma node.
  final double progressCardSpacing;

  /// Text style, including color, of the progress card label:
  /// `text/sm/strong` (14/20), per the Figma node.
  final TextStyle progressLabelTextStyle;
}

/// The modal surface: a hand-composed, token-for-token equivalent of
/// [DSModalDialog]'s chrome, with a configurable header-to-body gap.
///
/// ## Why this is not [DSModalDialog]
///
/// [DSModalDialog] hard-codes the vertical inset around its body:
/// `bodyPadding = padding.horizontalOnly + EdgeInsets.symmetric(vertical:
/// spacing.layout.m)`, i.e. 24 above *and* below the body, and applies it in
/// both of its body branches (inside `DSSingleChildScrollView` when
/// `wrapBodyInScrollView` is true, in a plain `Padding` when it is false). There
/// is no parameter, theme-data override or escape hatch that changes it, and
/// `spacing.layout.m` cannot be overridden through the token provider because
/// the same token also drives the surface padding, which Figma *does* want at
/// 24.
///
/// The Figma node asks for a different gap in each mode:
/// - details mode: the "Scrollview" follows the "Headline" with no
///   `LayoutSpacing` component at all, i.e. 24 (surface) + 40 (header) + 0 = 64
///   from the surface top to the first content pixel;
/// - list mode: an explicit 16px `spacing/component/m` sits between them,
///   i.e. 24 + 40 + 16 = 80.
///
/// Both render at 88 under [DSModalDialog]. A visual compensation inside the
/// body (negative offset, `Transform`, an over-tall `OverflowBox`) was rejected:
/// it either breaks the scroll extent and hit-testing, or forces the modal to
/// always occupy the full available height instead of shrinking to its content.
/// Rebuilding the arrangement is the only structural fix, so this widget does
/// exactly that.
///
/// ## What this costs, and what it does not
///
/// This is a deliberate reversal of the "DS chrome wins over Figma" default the
/// rest of this component follows: the user reviewed a side-by-side screenshot
/// comparison and chose Figma's tighter spacing. The cost is that the surface
/// arrangement is now duplicated here and can drift from `DSModalDialog`. It is
/// mirrored token for token (see [DeviceModalThemeData]) and every structural
/// decision below is copied from `ds_modal_dialog.dart`, including the
/// full-screen-on-small-form-factor rule and the `DSClearViewInsets` behavior;
/// should DS ever expose the body padding, this widget should be deleted in
/// favor of [DSModalDialog] again.
///
/// Nothing else is re-implemented: the barrier, alignment, route and inherited
/// themes still come from `showDSModalDialog`; the scrollable body is the public
/// [DSCustomScrollView], which applies the same DS hover-visible scrollbar and
/// the same right-gutter padding distribution as the `DSSingleChildScrollView`
/// [DSModalDialog] uses internally; the close button is a real
/// [DSButton.tertiary].
class _DeviceModalSurface extends StatelessWidget {
  const _DeviceModalSurface({
    required this.theme,
    required this.variant,
    required this.title,
    required this.onClose,
    required this.bodyTopGap,
    required this.body,
    required this.buttons,
  });

  final DeviceModalThemeData theme;
  final DSModalDialogVariant variant;
  final String title;
  final VoidCallback onClose;

  /// Vertical gap between the header row and the first body pixel.
  final double bodyTopGap;

  final Widget body;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final formFactor = DSFormFactor.of(context);
    // Copied from DSModalDialog.shouldDisplayFullScreen(): only the non-small
    // variants go full screen, and only on the small form factor. With this
    // component's default variant this is always false.
    final fullScreen =
        formFactor == DSFormFactor.small && variant != DSModalDialogVariant.small;
    // Same opt-out DSModalDialog offers: passing the DS `hideDialogCloseButton`
    // sentinel as onClose removes the close button.
    final showCloseButton = onClose != hideDialogCloseButton;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    // Equivalent of the DS-internal `DSClearViewInsets`: keeps the surface clear
    // of an on-screen keyboard.
    return MediaQuery.removeViewInsets(
      context: context,
      removeLeft: true,
      removeTop: true,
      removeRight: true,
      removeBottom: true,
      child: Padding(
        padding: viewInsets,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: theme.widthFor(variant).resolve(formFactor),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height -
                  (fullScreen ? 0 : theme.screenVerticalPadding),
            ),
            padding:
                fullScreen ? EdgeInsets.zero : theme.surfaceVerticalPadding,
            decoration: BoxDecoration(
              color: theme.surfaceBackground,
              borderRadius:
                  fullScreen ? BorderRadius.zero : theme.surfaceBorderRadius,
            ),
            child: Column(
              mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: theme.surfaceHorizontalPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: theme.titlePadding,
                          child: Text(
                            title,
                            style: theme.titleTextStyle,
                            // The Figma details variant ellipsis-truncates the
                            // device name, which DSModalDialog's unbounded Text
                            // could not do. A plain Text (rather than DSText) is
                            // kept so the title's color still resolves through
                            // the ambient DefaultTextStyle exactly as it did
                            // under DSModalDialog; the trade-off is that a
                            // truncated title has no hover tooltip.
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (showCloseButton)
                        DSButton.tertiary(
                          icon: DSIcons.close,
                          onPressed: onClose,
                        ),
                    ],
                  ),
                ),
                Flexible(
                  fit: fullScreen ? FlexFit.tight : FlexFit.loose,
                  child: DSCustomScrollView(
                    // Sizes the viewport to its content up to the available
                    // height, instead of always filling it. This is what
                    // DSModalDialog gets for free from SingleChildScrollView and
                    // what a plain CustomScrollView would not do — without it
                    // the modal would always be as tall as the screen allows.
                    shrinkWrap: true,
                    // DSCustomScrollView distributes this exactly like the
                    // DSSingleChildScrollView inside DSModalDialog: left, top
                    // and bottom inset the viewport, while the right inset is
                    // applied to the slivers so the scrollbar sits in the
                    // gutter rather than over the content.
                    padding: theme.surfaceHorizontalPadding.copyWith(
                      top: bodyTopGap,
                      // No footer toolbar to gap away from ("one-click" list
                      // mode has none — see DeviceModal.selectDevice): the
                      // surface's own 24px vertical padding is then the only
                      // space below the body.
                      bottom: buttons.isEmpty ? 0 : theme.bodyBottomGap,
                    ),
                    slivers: [SliverToBoxAdapter(child: body)],
                  ),
                ),
                Padding(
                  padding: theme.surfaceHorizontalPadding,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: theme.toolbarSpacing,
                      runSpacing: theme.toolbarSpacing,
                      children: buttons,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [Column] of the non-null [children], each followed by a gap: its own
/// [_Block.spacingAfter] override, or [defaultSpacing] when absent.
///
/// Every optional block of a [DeviceModal] body is passed in as a nullable
/// [_Block] (see [_Block.orNull]), so that omitting one leaves no stray gap
/// behind.
class _Stack extends StatelessWidget {
  const _Stack({required this.defaultSpacing, required this.children});

  final double defaultSpacing;
  final List<_Block?> children;

  @override
  Widget build(BuildContext context) {
    final blocks = children.nonNulls.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0)
            SizedBox(height: blocks[i - 1].spacingAfter ?? defaultSpacing),
          blocks[i].child,
        ],
      ],
    );
  }
}

/// One [_Stack] child, with an optional override for the gap that follows it.
class _Block {
  const _Block(this.child, {this.spacingAfter});

  /// Returns `null` (dropping the block, and any spacing around it) when
  /// [child] is null, for call sites building a block from an optional
  /// widget (e.g. [DeviceModal._buildNotification]).
  static _Block? orNull(Widget? child, {double? spacingAfter}) =>
      child == null ? null : _Block(child, spacingAfter: spacingAfter);

  final Widget child;

  /// Overrides [_Stack.defaultSpacing] for the gap following this block.
  final double? spacingAfter;
}

/// The details-mode metadata row: sublines, battery indicator and status tag,
/// each separated by a "·" divider, in one left-flowing group.
///
/// Verified against the Figma node directly (file "Equipment-Components",
/// node 5098:5220): the status tag is *not* pinned to the row's trailing
/// edge. It sits in the same flex flow as the other items, right after a "·"
/// divider from whichever item precedes it — the row's remaining width simply
/// trails empty after it, since nothing else follows. A dedicated
/// right-aligned slot (this widget's previous approach) reproduced the wrong
/// static frame: the trailing divider before the status tag is real (present
/// whenever an item precedes it), not the mock artifact it was assumed to be.
///
/// The group is a [Wrap] rather than a [Row] so that long sublines move onto
/// a second line instead of overflowing the modal.
class _DetailsInfoRow extends StatelessWidget {
  const _DetailsInfoRow({required this.details, required this.theme});

  final DeviceModalDeviceDetails details;
  final DeviceModalThemeData theme;

  @override
  Widget build(BuildContext context) {
    final subline1 = details.subline1;
    final subline2 = details.subline2;
    final batteryPercent = details.batteryPercent;
    final status = details.status;

    final items = <Widget>[
      if (subline1 != null) DSText(subline1, style: theme.infoTextStyle),
      if (subline2 != null) DSText(subline2, style: theme.infoTextStyle),
      if (batteryPercent != null)
        DSBatteryIndicator(
          batteryLevel: batteryPercent,
          lowLevelThreshold: details.lowBatteryThreshold,
        ),
      if (status != null)
        DSTag.status(text: status.label, statusType: status.tagType),
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) _InfoDivider(theme: theme),
          items[i],
        ],
      ],
    );
  }
}

/// The "·" glyph centered in a fixed-width box.
class _InfoDivider extends StatelessWidget {
  const _InfoDivider({required this.theme});

  final DeviceModalThemeData theme;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: theme.dividerWidth,
        // Decorative separator: assistive technology should not announce it.
        child: ExcludeSemantics(
          child: Center(
            child: DSText(_dividerGlyph, style: theme.infoTextStyle),
          ),
        ),
      );
}

/// The square image slot of the details mode.
///
/// Horizontally centered, unlike the rest of the [_Stack] body (which is
/// left-aligned): the Figma node's "Device information" group wraps the info
/// row and the image in a flex column with `items-center`, so the fixed
/// 240x240 image centers within the full content width while the full-width
/// info row above it is unaffected. Confirmed directly against the Figma node
/// (file "Equipment-Components", node 5098:5220).
class _DetailsImage extends StatelessWidget {
  const _DetailsImage({required this.image, required this.theme});

  final Widget? image;
  final DeviceModalThemeData theme;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox.square(
          dimension: theme.imageSize,
          // Decorative: the image conveys nothing the modal title and info
          // row do not already state, so it is kept out of the semantics tree
          // rather than announced as an unlabeled image. Same call
          // [DeviceCard] makes for its thumbnail.
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: theme.imageBorderRadius,
              child: image ?? ColoredBox(color: theme.imagePlaceholderColor),
            ),
          ),
        ),
      );
}

/// The bordered card holding a [DSProgressBar] and its label.
///
/// The bar itself is the real DS component, so the Figma node's 4px height,
/// neutral track and blue active fill all come from DS tokens. Only the
/// surrounding bordered surface is composed here: DS v51.0.0 has no
/// non-interactive bordered card ([DSContainer] has no border, and
/// [DSSpaciousCard] is an interactive surface), so the outline is built from
/// the `border/standard`, `border/width/standard` and `surface/standard`
/// tokens directly.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.theme});

  final DeviceModalProgress progress;
  final DeviceModalThemeData theme;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.progressCardBackground,
          borderRadius: theme.progressCardBorderRadius,
          border: theme.progressCardBorder,
        ),
        child: Padding(
          padding: theme.progressCardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: theme.progressCardSpacing,
            children: [
              DSProgressBar(value: progress.value),
              DSText(progress.label, style: theme.progressLabelTextStyle),
            ],
          ),
        ),
      );
}
