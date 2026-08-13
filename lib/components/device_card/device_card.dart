import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lightning_core_ui/lightning_core_ui.dart';

/// The connectivity status communicated by [DeviceCard]'s built-in status tag.
enum DeviceCardStatus {
  /// The device is online. Rendered as a success-styled "Online" tag.
  online,

  /// The device is offline. Rendered as a neutral-styled "Offline" tag.
  offline,
}

/// How a [DeviceCardStatus] is presented as a DS status tag.
///
/// Exposed so widgets that compose *with* [DeviceCard] — e.g. `DeviceModal`,
/// which shows the focused device's status in its own header row rather than on
/// a card — render exactly the same tag instead of duplicating the mapping.
extension DeviceCardStatusPresentation on DeviceCardStatus {
  /// The tag label.
  ///
  /// Hardcoded English, like the rest of this component: the project has no
  /// localizations of its own yet, and DS only localizes its own strings.
  String get label => switch (this) {
        DeviceCardStatus.online => 'Online',
        DeviceCardStatus.offline => 'Offline',
      };

  /// The DS status tag styling.
  DSStatusTagType get tagType => switch (this) {
        DeviceCardStatus.online => DSStatusTagType.success,
        DeviceCardStatus.offline => DSStatusTagType.neutral,
      };
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
                  text: status.label,
                  statusType: status.tagType,
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

/// The number of lines the subline text itself may occupy before it is
/// truncated with an ellipsis.
///
/// The battery indicator may add one more line on top of this budget; see
/// [_SublineRow].
const int _sublineMaxLines = 2;

/// The glyph separating the subline from an inline battery indicator.
const String _dividerGlyph = '·';

/// The ellipsis [DSText] renders for a truncated subline, mirrored here so the
/// measured last line matches the painted one.
///
/// This is the same character [RenderParagraph] uses for
/// [TextOverflow.ellipsis].
const String _ellipsis = '…';

/// Slack, in logical pixels, allowed when deciding whether the divider plus
/// the battery indicator still fit on the subline's last line.
///
/// Absorbs floating point noise from text measurement only; it is far below
/// one device pixel.
const double _inlineFitTolerance = 0.01;

/// The subline and the battery indicator, laid out as a single text flow.
///
/// The rules, in the order they apply:
///
/// - The subline wraps onto at most [_sublineMaxLines] lines. A subline that
///   would need a third line is truncated with a trailing ellipsis at the end
///   of line 2 — standard [DSText] `maxLines`/[TextOverflow.ellipsis]
///   semantics, which also gives the full string a hover tooltip.
/// - The "· + battery indicator" unit is an *inline trailing element*, but
///   only next to the subline's **first** line: if the subline is short
///   enough to fit on one line, the unit attaches to the end of it when there
///   is room. A subline that has already wrapped onto a second line never
///   gets an inline battery next to that second line, even if there would be
///   room — the battery always moves below in that case.
/// - Whenever the unit does not attach inline (no room on a single-line
///   subline, or the subline wrapped at all), the battery indicator alone
///   moves to one additional line below (a third line when the subline used
///   two), and the divider is not rendered at all — the divider only ever
///   separates the battery from subline text *on the same line*.
/// - The subline's two-line budget is independent of that decision: it is laid
///   out at the full available width either way, so bumping the battery onto
///   its own line never shortens the text. This is also why the whole thing is
///   not one `Text.rich` flow with a single `maxLines` cap: text lines fill
///   greedily, so no single cap can express "two lines for the subline, plus
///   one more only for the battery".
/// - With no subline the battery renders alone and, having nothing to be
///   divided from, without the divider.
///
/// This is implemented as a small render object ([_SublineFlow]) because the
/// inline-versus-own-line decision needs two measurements in the same layout
/// pass, before anything is positioned:
///
/// - the subline's *last line* geometry, which comes from a [TextPainter]
///   configured exactly like the [DSText] that paints the subline;
/// - the battery indicator's *real* width, which comes from laying out the
///   actual [DSBatteryIndicator] child. It cannot be derived from public DS
///   API — `DSBatteryIndicatorThemeData` (icon box, icon/text gap, percentage
///   text style) is `@internal` — and measuring the real widget keeps this
///   card correct if those internals change.
///
/// A [Wrap] (what this row used before) can make the inline-versus-own-line
/// decision on its own, but cannot drop the divider when the unit wraps, and
/// treats the subline as one unbreakable block rather than letting it wrap.
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
    // What the `Text` inside `DSText` will actually resolve the style to: an
    // inheriting style is merged onto the ambient DefaultTextStyle (which
    // DSSpaciousCard installs around its body). Resolving it here keeps the
    // measured text metrics identical to the painted ones, and gives the
    // directly painted divider the same treatment the `Text` widget it
    // replaced used to get.
    final resolvedSublineStyle = sublineStyle.inherit
        ? DefaultTextStyle.of(context).style.merge(sublineStyle)
        : sublineStyle;

    return _SublineFlow(
      subline: subline,
      sublineStyle: resolvedSublineStyle,
      // Figma gives the divider a fixed 16px box with the glyph centered
      // inside, rather than padding around the glyph.
      dividerWidth: theme.dividerWidth,
      // Figma specifies a `4px 0px` gap: the horizontal separation is already
      // provided by the divider box, so only the run spacing is non-zero.
      runSpacing: theme.sublineRowRunSpacing,
      textScaler: MediaQuery.textScalerOf(context),
      battery: batteryPercent == null
          ? null
          // Figma applies `opacities/disabled` to this group as its own group
          // opacity rather than swapping the icon/text colors, so the
          // low-battery warning color stays recognizable while dimmed.
          // DSBatteryIndicator exposes no disabled state, so the opacity is
          // applied around it.
          : Opacity(
              opacity: enabled ? 1 : theme.disabledOpacity,
              child: DSBatteryIndicator(
                batteryLevel: batteryPercent,
                lowLevelThreshold: lowBatteryThreshold,
              ),
            ),
    );
  }
}

/// The two children [_SublineFlow] positions.
///
/// The divider is deliberately not among them: it is painted directly by
/// [_RenderSublineFlow], which is both how it can be omitted entirely (rather
/// than merely hidden) when the battery is not inline, and how it stays out of
/// the semantics tree — it is a decorative separator that assistive tech
/// should not announce.
enum _SublineSlot { subline, battery }

/// Lays out the subline text and the battery indicator per the rules
/// documented on [_SublineRow].
class _SublineFlow
    extends SlottedMultiChildRenderObjectWidget<_SublineSlot, RenderBox> {
  const _SublineFlow({
    required this.subline,
    required this.sublineStyle,
    required this.battery,
    required this.dividerWidth,
    required this.runSpacing,
    required this.textScaler,
  });

  /// The subline text, or null when the battery renders on its own.
  final String? subline;

  /// The style [subline] is painted with, already resolved against the ambient
  /// [DefaultTextStyle].
  ///
  /// Also used for the divider glyph, which Figma renders in the same style.
  final TextStyle sublineStyle;

  /// The battery indicator, or null when it is hidden (no battery level, or
  /// the card is loading).
  final Widget? battery;

  /// Total width of the fixed box the divider glyph is centered in.
  final double dividerWidth;

  /// Vertical gap between the subline block and a battery indicator that did
  /// not fit inline.
  final double runSpacing;

  /// The ambient text scaler, forwarded so measurement matches what [DSText]
  /// renders.
  final TextScaler textScaler;

  /// The span used to measure [subline]; kept in sync with the [DSText] built
  /// in [childForSlot] by deriving both from the same two fields.
  TextSpan? get _sublineSpan {
    final subline = this.subline;
    return subline == null
        ? null
        : TextSpan(text: subline, style: sublineStyle);
  }

  TextSpan get _dividerSpan =>
      TextSpan(text: _dividerGlyph, style: sublineStyle);

  @override
  Iterable<_SublineSlot> get slots => _SublineSlot.values;

  @override
  Widget? childForSlot(_SublineSlot slot) {
    final subline = this.subline;
    return switch (slot) {
      _SublineSlot.subline => subline == null
          ? null
          : DSText(
              subline,
              style: sublineStyle,
              maxLines: _sublineMaxLines,
            ),
      _SublineSlot.battery => battery,
    };
  }

  @override
  _RenderSublineFlow createRenderObject(BuildContext context) =>
      _RenderSublineFlow(
        sublineSpan: _sublineSpan,
        dividerSpan: _dividerSpan,
        dividerWidth: dividerWidth,
        runSpacing: runSpacing,
        textScaler: textScaler,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSublineFlow renderObject,
  ) {
    renderObject
      ..sublineSpan = _sublineSpan
      ..dividerSpan = _dividerSpan
      ..dividerWidth = dividerWidth
      ..runSpacing = runSpacing
      ..textScaler = textScaler;
  }
}

/// The result of one [_RenderSublineFlow] layout pass.
///
/// Offsets are relative to the render object's top left corner. A null
/// [dividerOffset] means the divider is not painted at all for this layout.
class _SublineGeometry {
  const _SublineGeometry({
    required this.size,
    this.sublineOffset = Offset.zero,
    this.batteryOffset = Offset.zero,
    this.dividerOffset,
  });

  final Size size;
  final Offset sublineOffset;
  final Offset batteryOffset;
  final Offset? dividerOffset;
}

/// Implements the layout described on [_SublineRow].
class _RenderSublineFlow extends RenderBox
    with SlottedContainerRenderObjectMixin<_SublineSlot, RenderBox> {
  _RenderSublineFlow({
    required this._sublineSpan,
    required this._dividerSpan,
    required this._dividerWidth,
    required this._runSpacing,
    required this._textScaler,
  });

  /// Measures — but never paints — the subline, to learn where its last line
  /// ends and how tall that line is.
  ///
  /// Configured to match the `Text` that [DSText] paints: left-to-right,
  /// start-aligned, capped at [_sublineMaxLines] with an ellipsis. The
  /// left-to-right assumption mirrors [DSText]'s own internal measurement,
  /// which is likewise hard-coded to it.
  final TextPainter _sublinePainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: _sublineMaxLines,
    ellipsis: _ellipsis,
  );

  /// Paints the divider glyph. See [_SublineSlot] for why it is not a child.
  final TextPainter _dividerPainter =
      TextPainter(textDirection: TextDirection.ltr);

  Offset? _dividerOffset;

  TextSpan? _sublineSpan;
  set sublineSpan(TextSpan? value) {
    if (_sublineSpan == value) return;
    _sublineSpan = value;
    markNeedsLayout();
  }

  TextSpan _dividerSpan;
  set dividerSpan(TextSpan value) {
    if (_dividerSpan == value) return;
    _dividerSpan = value;
    markNeedsLayout();
  }

  double _dividerWidth;
  set dividerWidth(double value) {
    if (_dividerWidth == value) return;
    _dividerWidth = value;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    markNeedsLayout();
  }

  RenderBox? get _sublineChild => childForSlot(_SublineSlot.subline);

  RenderBox? get _batteryChild => childForSlot(_SublineSlot.battery);

  /// Paint order, which is also the order the children are visited in for
  /// semantics. Hit testing walks it in reverse.
  @override
  Iterable<RenderBox> get children => [
        ?_sublineChild,
        ?_batteryChild,
      ];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void dispose() {
    _sublinePainter.dispose();
    _dividerPainter.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    final geometry = _computeGeometry(constraints, dry: false);
    size = geometry.size;
    _offsetOf(_sublineChild)?.offset = geometry.sublineOffset;
    _offsetOf(_batteryChild)?.offset = geometry.batteryOffset;
    _dividerOffset = geometry.dividerOffset;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeGeometry(constraints, dry: true).size;

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
        _sublineChild?.getMinIntrinsicWidth(height) ?? 0,
        _batteryChild?.getMinIntrinsicWidth(height) ?? 0,
      );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final subline = _sublineChild?.getMaxIntrinsicWidth(height);
    final battery = _batteryChild?.getMaxIntrinsicWidth(height);
    if (subline == null || battery == null) {
      return subline ?? battery ?? 0;
    }
    // Widest sensible layout: the whole subline on one line, with the divider
    // and the battery indicator inline behind it.
    return subline + _dividerWidth + battery;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _computeGeometry(BoxConstraints(maxWidth: width), dry: true).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  BoxParentData? _offsetOf(RenderBox? child) =>
      child?.parentData as BoxParentData?;

  _SublineGeometry _computeGeometry(
    BoxConstraints constraints, {
    required bool dry,
  }) {
    final maxWidth = constraints.maxWidth;
    final childConstraints = BoxConstraints(maxWidth: maxWidth);
    Size measure(RenderBox child) => dry
        ? child.getDryLayout(childConstraints)
        : (child..layout(childConstraints, parentUsesSize: true)).size;

    final subline = _sublineChild;
    final battery = _batteryChild;
    final sublineSize = subline == null ? null : measure(subline);
    final batterySize = battery == null ? null : measure(battery);

    if (batterySize == null) {
      return _SublineGeometry(
        size: constraints.constrain(sublineSize ?? Size.zero),
      );
    }
    if (sublineSize == null) {
      // The battery renders alone: no subline means nothing to divide it from,
      // so no divider either.
      return _SublineGeometry(size: constraints.constrain(batterySize));
    }

    _sublinePainter
      ..text = _sublineSpan ?? const TextSpan(text: '')
      ..textScaler = _textScaler
      ..layout(maxWidth: maxWidth);
    // Guards against a painter/child disagreement (e.g. a skeleton bone
    // standing in for the text) clipping the block.
    final textHeight = math.max(sublineSize.height, _sublinePainter.height);

    final lines = _sublinePainter.computeLineMetrics();
    final lastLine = lines.isEmpty ? null : lines.last;
    final lastLineEnd = lastLine == null ? 0.0 : lastLine.left + lastLine.width;
    final lastLineBaseline = lastLine?.baseline ??
        _sublinePainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    // Inline placement is only attempted next to the subline's first line.
    // A subline that has already wrapped onto a second line always puts the
    // battery on its own line below, even if that second line has room.
    final fitsInline = lines.length <= 1 &&
        lastLineEnd + _dividerWidth + batterySize.width <=
            maxWidth + _inlineFitTolerance;

    if (!fitsInline) {
      // One extra line below everything the subline used, battery only.
      return _SublineGeometry(
        size: constraints.constrain(Size(
          math.max(sublineSize.width, batterySize.width),
          textHeight + _runSpacing + batterySize.height,
        )),
        batteryOffset: Offset(0, textHeight + _runSpacing),
      );
    }

    // Centered on the last line rather than on the whole text block, so a
    // wrapped subline keeps the indicator next to the line it belongs to.
    final lastLineTop =
        lastLine == null ? 0.0 : lastLine.baseline - lastLine.ascent;
    final lastLineBottom = lastLine == null
        ? textHeight
        : lastLine.baseline + lastLine.descent;
    final batteryLeft = lastLineEnd + _dividerWidth;
    final batteryTop = (lastLineTop + lastLineBottom - batterySize.height) / 2;
    // An indicator taller than the line it sits on pushes the whole block
    // down instead of being clipped at the top. On a single-line subline this
    // reproduces the vertical centering the previous [Wrap] produced.
    final shift = math.max(0.0, -batteryTop);

    _dividerPainter
      ..text = _dividerSpan
      ..textScaler = _textScaler
      ..layout();
    final dividerBaseline =
        _dividerPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    return _SublineGeometry(
      size: constraints.constrain(Size(
        math.max(sublineSize.width, batteryLeft + batterySize.width),
        math.max(textHeight, batteryTop + batterySize.height) + shift,
      )),
      sublineOffset: Offset(0, shift),
      batteryOffset: Offset(batteryLeft, batteryTop + shift),
      dividerOffset: Offset(
        // Centered in its fixed-width box, and sharing the last line's
        // baseline since it is set in the subline's own style.
        lastLineEnd + (_dividerWidth - _dividerPainter.width) / 2,
        lastLineBaseline - dividerBaseline + shift,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final subline = _sublineChild;
    if (subline != null) {
      context.paintChild(subline, offset + _offsetOf(subline)!.offset);
    }
    final dividerOffset = _dividerOffset;
    if (dividerOffset != null) {
      _dividerPainter.paint(context.canvas, offset + dividerOffset);
    }
    final battery = _batteryChild;
    if (battery != null) {
      context.paintChild(battery, offset + _offsetOf(battery)!.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children.toList().reversed) {
      final childOffset = _offsetOf(child)!.offset;
      final hit = result.addWithPaintOffset(
        offset: childOffset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
