import 'package:flutter/material.dart';
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
///
/// ## Relationship to the Figma source of truth
///
/// The design lives in Figma "Equipment-Components", node `4837:19131`. Where
/// that node and [DSSpaciousCard] disagree on card *chrome*, this widget
/// follows [DSSpaciousCard] (and therefore the current DS tokens) rather than
/// re-implementing the chrome by hand:
///
/// - Content padding: Figma shows `spacing/component/m` (16), DS uses
///   `spacing.layout.m` (24 on non-small form factors).
/// - Thumbnail size: Figma shows 120x120, DS uses `image.size.card`
///   (128 on non-small, 64 on small).
///
/// Everything the card *content* controls does follow the Figma node exactly,
/// including the thumbnail's `border/radius/small` corner (which deliberately
/// differs from the card's own `border/radius/standard`).
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.name,
    this.subline,
    this.thumbnail,
    this.batteryPercent,
    this.lowBatteryThreshold = 30,
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

  /// Battery level 0-100. The battery indicator is hidden when null.
  ///
  /// Forwarded verbatim to [DSBatteryIndicator.batteryLevel], which asserts
  /// the 0-100 range.
  final int? batteryPercent;

  /// At or below this battery level the battery indicator switches to the
  /// critical icon color.
  ///
  /// Forwarded to [DSBatteryIndicator.lowLevelThreshold]; the default of 30
  /// mirrors that widget's own default.
  final int lowBatteryThreshold;

  /// The connectivity status shown as a tag below the subline/battery row.
  /// `null` hides the tag entirely.
  final DeviceCardStatus? status;

  final bool selected;
  final bool enabled;

  /// Puts the card into its loading state and disables interaction.
  ///
  /// This does **not** swap in a separate placeholder layout. The real content
  /// tree is built either way; [DSSkeletonizer] merely publishes the ambient
  /// skeleton flag, and each skeleton-aware DS widget below renders itself as
  /// a bone whose shape is derived from the content it was actually given.
  ///
  /// The practical consequence is that whatever [name] and [subline] the
  /// caller passes while loading determines the bone widths, so callers should
  /// pass representative placeholder (or last-known) strings rather than empty
  /// ones.
  ///
  /// Two parts of the card are not covered by that mechanism, and are instead
  /// suppressed outright while loading:
  ///
  /// - The tags row, matching the Figma "Disabled + loading" variant, which
  ///   renders no tags row at all.
  /// - The battery indicator: [DSBatteryIndicator] is not skeleton-aware in
  ///   `lightning_core_ui` v51.0.0 — it neither wraps itself in the DS
  ///   skeleton wrapper nor is listed among `DSSkeletonizer`'s supported
  ///   widgets — so left alone it would keep rendering as sharp, real content
  ///   (icon and percentage) next to the skeleton bones around it. This card
  ///   works around that package gap by hiding the battery indicator outright
  ///   while loading, the same way the tags row is hidden, rather than
  ///   showing a mismatched mix of real and skeleton content.
  ///
  /// The thumbnail *is* covered: `DSSpaciousCard` replaces its image slot
  /// with a bone while skeleton mode is on, and this card always supplies an
  /// [DSSpaciousCard.imageWidget], so the slot is always present to be boned.
  final bool isLoading;

  /// Card is non-interactive (no hover/press/focus visuals, not keyboard
  /// activatable) when null.
  final VoidCallback? onTap;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// The fixed card width from the Figma node.
  final double width;

  bool get _interactive => enabled && !isLoading && onTap != null;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);
    final theme = DeviceCardThemeData(tokens);
    final status = this.status;

    final card = DSSpaciousCard(
      // The body is built identically whether or not the card is loading.
      // `DSText` opts into skeleton mode on its own, so while [isLoading] the
      // name and subline render as bones whose width and height are derived
      // from the text and text style actually passed in — which is how the DS
      // skeleton mechanism is meant to be driven. See [isLoading].
      body: _DeviceCardBody(
        name: name,
        subline: subline,
        batteryPercent: batteryPercent,
        lowBatteryThreshold: lowBatteryThreshold,
        enabled: enabled,
        isLoading: isLoading,
        theme: theme,
      ),
      // The Figma node renders no tags row at all while loading.
      tags: (isLoading || status == null)
          ? null
          : [
              // Per Figma the whole tags row carries its own
              // `opacities/disabled`, independently of the text-color swap
              // applied to the name/subline. With a single tag, dimming the
              // tag is equivalent to dimming the row.
              Opacity(
                opacity: enabled ? 1 : theme.disabledOpacity,
                child: DSTag.status(
                  text:
                      status == DeviceCardStatus.online ? 'Online' : 'Offline',
                  statusType: status == DeviceCardStatus.online
                      ? DSStatusTagType.success
                      : DSStatusTagType.neutral,
                ),
              ),
            ],
      // Decorative: the thumbnail conveys no information beyond what [name]
      // and [subline] already state, so it is excluded from the semantics
      // tree rather than announced as an unlabeled image.
      //
      // Built identically whether or not the card is loading, so the slot
      // keeps its real `border/radius/small` corner in both states.
      imageWidget: ExcludeSemantics(
        // DSSpaciousCard clips the image slot with the card's standard
        // radius; the Figma node asks for the smaller `border/radius/small`
        // on the thumbnail specifically. Clipping again with the smaller
        // radius inside the DS clip yields the intended corner.
        child: ClipRRect(
          borderRadius: theme.thumbnailBorderRadius,
          child: thumbnail ?? ColoredBox(color: tokens.surface.subdued),
        ),
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
        // The single mechanism that produces the loading state: it publishes
        // the ambient skeleton flag that every skeleton-aware DS widget in
        // the card below reads. There is deliberately no parallel, hand-built
        // placeholder tree. See [isLoading].
        child: DSSkeletonizer(enabled: isLoading, child: card),
      ),
    );
  }
}

/// Content-level design tokens for [DeviceCard].
///
/// The outer card chrome (background, border, two-layer `shadows.elevation1`,
/// hover/press/focus visuals, keyboard activation) is entirely supplied by
/// [DSSpaciousCard]; this theme only covers the content DSSpaciousCard has no
/// opinion about. It follows the same token-derivation convention used by the
/// DS package's internal `*ThemeData` classes (e.g. `DSCheckboxThemeData`): a
/// plain class whose fields are computed once from [DSTokensData] in the
/// constructor.
class DeviceCardThemeData {
  DeviceCardThemeData(DSTokensData d)
      : nameTextStyle = d.text.textBaseStrong,
        sublineTextStyle = d.text.textBase,
        textColorStandard = d.text.standard,
        textColorDisabled = d.text.disabled,
        disabledOpacity = d.opacities.disabled,
        dividerWidth = d.spacing.component.m,
        sublineRowRunSpacing = d.spacing.component.xxs,
        thumbnailBorderRadius = BorderRadius.circular(d.border.radius.small);

  /// Text style for the device name.
  final TextStyle nameTextStyle;

  /// Text style for the subline (e.g. serial number).
  final TextStyle sublineTextStyle;

  /// Text color used when the card is enabled.
  final Color textColorStandard;

  /// Text color used when the card is disabled.
  final Color textColorDisabled;

  /// Opacity applied to the battery indicator group and the tags row when the
  /// card is disabled.
  ///
  /// [DSBatteryIndicator] has no disabled state of its own, so this card
  /// applies the token as a group opacity around it.
  final double disabledOpacity;

  /// Total width of the "·" divider between the subline and the battery
  /// indicator. The glyph is centered inside it.
  final double dividerWidth;

  /// Vertical gap between the two lines of the subline row when the battery
  /// indicator wraps onto its own line.
  final double sublineRowRunSpacing;

  /// Corner radius of the thumbnail, in every state including loading.
  ///
  /// Deliberately `border/radius/small`, smaller than the card's own
  /// `border/radius/standard`, per the Figma node.
  ///
  /// A static Figma "loading" frame shows the thumbnail placeholder at
  /// `border/radius/standard` instead. That is not reproduced here: the DS
  /// skeleton mechanism derives bones from the real content, so the real
  /// component keeps its own radius while loading. Real component behavior
  /// wins over the static mockup.
  final BorderRadius thumbnailBorderRadius;
}

class _DeviceCardBody extends StatelessWidget {
  const _DeviceCardBody({
    required this.name,
    required this.subline,
    required this.batteryPercent,
    required this.lowBatteryThreshold,
    required this.enabled,
    required this.isLoading,
    required this.theme,
  });

  final String name;
  final String? subline;
  final int? batteryPercent;
  final int lowBatteryThreshold;
  final bool enabled;
  final bool isLoading;
  final DeviceCardThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Per Figma the name and subline swap to `text/disabled` when the card is
    // disabled, whereas the battery group and the tags row instead keep their
    // standard colors under a group opacity.
    final textColor =
        enabled ? theme.textColorStandard : theme.textColorDisabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The name is the one text in this card that Figma does mark as
        // truncating (`overflow-hidden text-ellipsis whitespace-nowrap`),
        // which is DSText's default behavior.
        DSText(name, style: theme.nameTextStyle.copyWith(color: textColor)),
        _SublineRow(
          subline: subline,
          // Hidden while loading: see [DeviceCard.isLoading].
          batteryPercent: isLoading ? null : batteryPercent,
          lowBatteryThreshold: lowBatteryThreshold,
          textColor: textColor,
          enabled: enabled,
          theme: theme,
        ),
      ],
    );
  }
}

/// The subline and the battery indicator.
///
/// Figma models this as a wrapping flex row in which the "·" divider plus the
/// battery indicator form a single non-shrinking unit. When that unit does not
/// fit beside the subline it moves to a line of its own instead of squeezing
/// the subline — so a [Wrap] with the divider and indicator grouped into one
/// child is the direct Flutter equivalent.
class _SublineRow extends StatelessWidget {
  const _SublineRow({
    required this.subline,
    required this.batteryPercent,
    required this.lowBatteryThreshold,
    required this.textColor,
    required this.enabled,
    required this.theme,
  });

  final String? subline;
  final int? batteryPercent;
  final int lowBatteryThreshold;
  final Color textColor;
  final bool enabled;
  final DeviceCardThemeData theme;

  @override
  Widget build(BuildContext context) {
    final subline = this.subline;
    final batteryPercent = this.batteryPercent;
    if (subline == null && batteryPercent == null) {
      return const SizedBox.shrink();
    }

    final sublineStyle = theme.sublineTextStyle.copyWith(color: textColor);

    final batteryUnit = batteryPercent == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subline != null)
                // Purely decorative separator; assistive tech should not
                // announce it. Figma gives the divider a fixed 16px box with
                // the glyph centered inside, rather than padding around it.
                ExcludeSemantics(
                  child: SizedBox(
                    width: theme.dividerWidth,
                    child: Text(
                      '·',
                      textAlign: TextAlign.center,
                      style: sublineStyle,
                    ),
                  ),
                ),
              // Figma applies `opacities/disabled` to this group as its own
              // group opacity rather than swapping the icon/text colors, so
              // the low-battery warning color stays recognizable while
              // dimmed. DSBatteryIndicator exposes no disabled state, so the
              // opacity is applied around it.
              Opacity(
                opacity: enabled ? 1 : theme.disabledOpacity,
                child: DSBatteryIndicator(
                  batteryLevel: batteryPercent,
                  lowLevelThreshold: lowBatteryThreshold,
                ),
              ),
            ],
          );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      // Figma specifies a `4px 0px` gap: the horizontal separation is already
      // provided by the divider box, so only the run spacing is non-zero.
      runSpacing: theme.sublineRowRunSpacing,
      children: [
        // Once the battery unit wraps away, the subline gets the card's full
        // content width, which is the behavior the Figma node describes. The
        // DSText ellipsis only ever engages for a subline longer than the
        // whole card — the reference node would silently clip there, which
        // would drop the text with no tooltip and no way to read it.
        if (subline != null) DSText(subline, style: sublineStyle),
        ?batteryUnit,
      ],
    );
  }
}
