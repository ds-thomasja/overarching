import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lightning_core_ui/lightning_core_ui.dart';

/// The connectivity status communicated by [DeviceCard]'s built-in status tag.
enum DeviceCardStatus {
  /// The device is online. Rendered as a success-styled "Online" tag.
  online,

  /// The device is offline. Rendered as a neutral-styled "Offline" tag.
  offline,
}

/// A selectable card summarizing a connected device: thumbnail, name,
/// serial/status line, optional battery level, and a connectivity status tag.
///
/// Built on top of [DSSpaciousCard], which already implements everything a
/// card needs to behave like the rest of the DS: token-driven background/
/// border/shadow per [DSClickableState], keyboard activation (Enter/Space),
/// mouse hover/press/focus visuals, and disabled-image opacity. This widget
/// only supplies the device-specific content that [DSSpaciousCard] has no
/// opinion about — the name/subline/battery block and the status tag.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.name,
    this.subline,
    this.thumbnail,
    this.batteryPercent,
    this.status = DeviceCardStatus.online,
    this.selected = false,
    this.enabled = true,
    this.isLoading = false,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.width = 438,
  });

  /// Primary device name/title.
  final String name;

  /// Secondary line, e.g. a serial number ("SN:865562").
  final String? subline;

  /// Widget rendered in the thumbnail slot. Falls back to a plain placeholder
  /// box when omitted.
  final Widget? thumbnail;

  /// Battery level 0-100. The battery icon/percentage is hidden when null.
  final int? batteryPercent;

  /// The connectivity status shown as a tag below the subline/battery row.
  /// `null` hides the tag entirely.
  final DeviceCardStatus? status;

  final bool selected;
  final bool enabled;

  /// Shows skeleton placeholders instead of content and disables
  /// interaction while true.
  final bool isLoading;

  /// Card is non-interactive (no hover/press/focus visuals, not keyboard
  /// activatable) when null.
  final VoidCallback? onTap;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  final double width;

  bool get _interactive => enabled && !isLoading && onTap != null;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);
    final theme = DeviceCardThemeData(tokens);
    final textColor = enabled ? theme.textColorStandard : theme.textColorDisabled;
    final status = this.status;

    final card = DSSpaciousCard(
      body: _DeviceCardBody(
        name: name,
        subline: subline,
        batteryPercent: batteryPercent,
        enabled: enabled,
        textColor: textColor,
        theme: theme,
      ),
      tags: status == null
          ? null
          : [
              DSTag.status(
                text: status == DeviceCardStatus.online ? 'Online' : 'Offline',
                statusType: status == DeviceCardStatus.online
                    ? DSStatusTagType.success
                    : DSStatusTagType.neutral,
              ),
            ],
      // Decorative: the thumbnail conveys no information beyond what [name]
      // and [subline] already state, so it is excluded from the semantics
      // tree rather than announced as an unlabeled image.
      imageWidget: ExcludeSemantics(
        child: thumbnail ?? ColoredBox(color: tokens.surface.subdued),
      ),
      selected: selected,
      focusNode: focusNode,
      autofocus: autofocus,
      onPressed: _interactive ? onTap : null,
    );

    return Semantics(
      // Exposed unconditionally so assistive tech reports the correct role,
      // enabled and selected state even when the card is currently
      // non-interactive (e.g. disabled or still loading).
      button: true,
      enabled: enabled,
      selected: selected,
      child: SizedBox(
        width: width,
        child: DSSkeletonizer(enabled: isLoading, child: card),
      ),
    );
  }
}

/// Content-level design tokens for [DeviceCard].
///
/// The outer card chrome (background, border, shadow, hover/press/focus
/// visuals, keyboard activation) is entirely supplied by [DSSpaciousCard];
/// this theme only covers the content DSSpaciousCard has no opinion about —
/// the name/subline/battery text styles and colors. It follows the same
/// token-derivation convention used by the DS package's internal
/// `*ThemeData` classes (e.g. `DSCheckboxThemeData`): a plain class whose
/// fields are computed once from [DSTokensData] in the constructor.
class DeviceCardThemeData {
  DeviceCardThemeData(DSTokensData d)
      : nameTextStyle = d.text.textBaseStrong,
        sublineTextStyle = d.text.textBase,
        batteryTextStyle = d.text.textSmStrong,
        textColorStandard = d.text.standard,
        textColorDisabled = d.text.disabled,
        iconColorStandard = d.icon.standard,
        iconColorDisabled = d.icon.disabled,
        disabledOpacity = d.opacities.disabled,
        dividerSpacing = d.spacing.component.xxs,
        batteryIconSpacing = d.spacing.component.xxs;

  /// Text style for the device name.
  final TextStyle nameTextStyle;

  /// Text style for the subline (e.g. serial number).
  final TextStyle sublineTextStyle;

  /// Text style for the battery percentage.
  final TextStyle batteryTextStyle;

  /// Text color used when the card is enabled.
  final Color textColorStandard;

  /// Text color used when the card is disabled.
  final Color textColorDisabled;

  /// Battery icon color used when the card is enabled.
  final Color iconColorStandard;

  /// Battery icon color used when the card is disabled.
  final Color iconColorDisabled;

  /// Opacity applied to the battery indicator when the card is disabled.
  final double disabledOpacity;

  /// Horizontal padding around the "·" divider between the subline and the
  /// battery indicator.
  final double dividerSpacing;

  /// Spacing between the battery icon and its percentage text.
  final double batteryIconSpacing;
}

class _DeviceCardBody extends StatelessWidget {
  const _DeviceCardBody({
    required this.name,
    required this.subline,
    required this.batteryPercent,
    required this.enabled,
    required this.textColor,
    required this.theme,
  });

  final String name;
  final String? subline;
  final int? batteryPercent;
  final bool enabled;
  final Color textColor;
  final DeviceCardThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DSText(
          name,
          style: theme.nameTextStyle.copyWith(color: textColor),
        ),
        _SublineRow(
          subline: subline,
          batteryPercent: batteryPercent,
          textColor: textColor,
          enabled: enabled,
          theme: theme,
        ),
      ],
    );
  }
}

/// Renders the subline and battery indicator on one line, letting the
/// subline ellipsize first if space is tight. Using [Flexible] inside a
/// [Row] (rather than measuring text widths by hand) keeps this correct
/// under RTL layouts and text-scale changes for free.
class _SublineRow extends StatelessWidget {
  const _SublineRow({
    required this.subline,
    required this.batteryPercent,
    required this.textColor,
    required this.enabled,
    required this.theme,
  });

  final String? subline;
  final int? batteryPercent;
  final Color textColor;
  final bool enabled;
  final DeviceCardThemeData theme;

  @override
  Widget build(BuildContext context) {
    final subline = this.subline;
    final batteryPercent = this.batteryPercent;
    if (subline == null && batteryPercent == null) return const SizedBox.shrink();

    final sublineStyle = theme.sublineTextStyle.copyWith(color: textColor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (subline != null) Flexible(child: DSText(subline, style: sublineStyle)),
        if (subline != null && batteryPercent != null)
          // Purely decorative separator between the subline and the battery
          // indicator; assistive tech should not announce it.
          ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.dividerSpacing),
              child: Text('·', style: sublineStyle),
            ),
          ),
        if (batteryPercent != null)
          _BatteryGroup(percent: batteryPercent, enabled: enabled, theme: theme),
      ],
    );
  }
}

class _BatteryGroup extends StatelessWidget {
  const _BatteryGroup({required this.percent, required this.enabled, required this.theme});

  final int percent;
  final bool enabled;
  final DeviceCardThemeData theme;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    final region = DSRegion.of(context);
    final formatted =
        NumberFormat.percentPattern(region.localizations.localeName).format(clamped / 100);

    return Opacity(
      opacity: enabled ? 1 : theme.disabledOpacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSIcon.small(iconRef: _batteryIconFor(clamped), color: theme.iconColorStandard),
          SizedBox(width: theme.batteryIconSpacing),
          DSText(
            formatted,
            style: theme.batteryTextStyle.copyWith(color: theme.textColorStandard),
          ),
        ],
      ),
    );
  }
}

/// Maps a battery percentage onto the closest DS battery glyph. The DS icon
/// set only exports discrete levels (no continuous fill), so the mapping
/// below buckets the range into five bands.
DSIconRef _batteryIconFor(int percent) {
  if (percent <= 10) return DSIcons.batteryEmpty;
  if (percent <= 35) return DSIcons.batteryLow;
  if (percent <= 65) return DSIcons.batteryMid;
  if (percent <= 90) return DSIcons.batteryHigh;
  return DSIcons.batteryFull;
}
