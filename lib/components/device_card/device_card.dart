import 'package:flutter/material.dart';

/// A selectable card summarizing a connected device: thumbnail, name,
/// serial/status line, optional battery level, and an "Online" tag.
///
/// Hover, pressed, and keyboard-focus visuals are derived from real user
/// input (mouse/keyboard) rather than exposed as a `state` parameter, so the
/// widget behaves correctly under actual interaction instead of a fixed
/// enum a caller could set inconsistently with real input.
class DeviceCard extends StatefulWidget {
  const DeviceCard({
    super.key,
    required this.name,
    this.subline,
    this.thumbnail,
    this.batteryPercent,
    this.showOnlineTag = true,
    this.selected = false,
    this.enabled = true,
    this.isLoading = false,
    this.onTap,
    this.width = 438,
  });

  /// Primary device name/title.
  final String name;

  /// Secondary line, e.g. a serial number ("SN:865562").
  final String? subline;

  /// Widget rendered in the 120x120 thumbnail slot. Falls back to a plain
  /// placeholder box when omitted.
  final Widget? thumbnail;

  /// Battery level 0-100. The battery icon/percentage is hidden when null.
  final int? batteryPercent;

  /// Whether to show the built-in "Online" status tag.
  final bool showOnlineTag;

  final bool selected;
  final bool enabled;

  /// Shows skeleton placeholders instead of content and disables
  /// interaction while true.
  final bool isLoading;

  /// Card is non-interactive (no hover/press/focus visuals) when null.
  final VoidCallback? onTap;

  final double width;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

enum _CardVisualState { standard, hovered, pressed, focused, disabled }

class _DeviceCardState extends State<DeviceCard> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  late final AnimationController _skeletonController;
  late final Animation<Color?> _skeletonColor;

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(vsync: this, duration: _skeletonPulseDuration);
    _skeletonColor = ColorTween(begin: _surfaceSkeleton, end: _surfaceSkeletonPulse)
        .animate(CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut));
    if (widget.isLoading) _skeletonController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading == oldWidget.isLoading) return;
    if (widget.isLoading) {
      _skeletonController.repeat(reverse: true);
    } else {
      _skeletonController.stop();
    }
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  bool get _interactive =>
      widget.enabled && !widget.isLoading && widget.onTap != null;

  _CardVisualState get _visualState {
    if (!widget.enabled) return _CardVisualState.disabled;
    if (!_interactive) return _CardVisualState.standard;
    if (_pressed) return _CardVisualState.pressed;
    if (_hovered) return _CardVisualState.hovered;
    if (_focused) return _CardVisualState.focused;
    return _CardVisualState.standard;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.isLoading ? _CardVisualState.standard : _visualState;

    Widget card = Container(
      width: widget.width,
      padding: const EdgeInsets.all(_spacingM),
      decoration: _decorationFor(state),
      child: widget.isLoading ? _buildSkeleton() : _buildContent(state),
    );

    if (_interactive) {
      card = Semantics(
        button: true,
        enabled: widget.enabled,
        selected: widget.selected,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Focus(
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: GestureDetector(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: card,
            ),
          ),
        ),
      );
    }

    return card;
  }

  BoxDecoration _decorationFor(_CardVisualState state) {
    return BoxDecoration(
      color: _backgroundColor(widget.selected, state),
      borderRadius: BorderRadius.circular(_radiusStandard),
      border: Border.fromBorderSide(_borderSideFor(state)),
      boxShadow: _cardShadow,
    );
  }

  Widget _buildContent(_CardVisualState state) {
    final disabled = state == _CardVisualState.disabled;
    final textColor = disabled ? _textDisabled : _textStandard;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Opacity(
          opacity: disabled ? _disabledOpacity : 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radiusSmall),
            child: SizedBox(
              width: 120,
              height: 120,
              child: widget.thumbnail ?? const ColoredBox(color: _surfaceSubdued),
            ),
          ),
        ),
        const SizedBox(width: _spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _textBaseStrong.copyWith(color: textColor),
              ),
              _SublineRow(
                subline: widget.subline,
                batteryPercent: widget.batteryPercent,
                textColor: textColor,
                disabled: disabled,
              ),
              if (widget.showOnlineTag)
                const Padding(
                  padding: EdgeInsets.only(top: _spacingXs),
                  child: _StatusTag(label: 'Online'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return AnimatedBuilder(
      animation: _skeletonColor,
      builder: (context, child) {
        final color = _skeletonColor.value ?? _surfaceSkeleton;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SkeletonBox(width: 120, height: 120, color: color),
            const SizedBox(width: _spacingM),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    child: Align(alignment: Alignment.centerLeft, child: _SkeletonPill(width: 96, color: color)),
                  ),
                  SizedBox(
                    height: 24,
                    child: Align(alignment: Alignment.centerLeft, child: _SkeletonPill(width: 144, color: color)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

Color _backgroundColor(bool selected, _CardVisualState state) {
  switch (state) {
    case _CardVisualState.hovered:
      return selected ? _surfaceSelectedHovered : _surfaceHovered;
    case _CardVisualState.pressed:
      return selected ? _surfaceSelectedPressed : _surfacePressed;
    case _CardVisualState.focused:
    case _CardVisualState.disabled:
    case _CardVisualState.standard:
      return selected ? _surfaceSelectedStandard : _surfaceStandard;
  }
}

BorderSide _borderSideFor(_CardVisualState state) {
  if (state == _CardVisualState.focused) {
    return const BorderSide(color: _borderFocused, width: _borderWidthFocus);
  }
  return const BorderSide(color: _borderSubdued, width: _borderWidthStandard);
}

/// Renders the subline and battery indicator on one line when they fit.
///
/// When the subline is too long to share a line with the battery indicator,
/// the subline truncates to its own full-width line and the battery
/// indicator drops to a second line without the "·" divider, matching the
/// Figma overflow variant (node 5104:20550).
class _SublineRow extends StatelessWidget {
  const _SublineRow({
    required this.subline,
    required this.batteryPercent,
    required this.textColor,
    required this.disabled,
  });

  final String? subline;
  final int? batteryPercent;
  final Color textColor;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    if (subline == null && batteryPercent == null) return const SizedBox.shrink();

    final sublineStyle = _textBase.copyWith(color: textColor);
    final batteryTextStyle = _textSmStrong.copyWith(color: _textStandard);

    if (subline == null) {
      return _BatteryGroup(percent: batteryPercent!, textStyle: batteryTextStyle, disabled: disabled);
    }

    if (batteryPercent == null) {
      return Text(subline!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sublineStyle);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const dotWidth = 16.0;
        final batteryWidth = _textWidth('$batteryPercent%', batteryTextStyle) + 24 + 4;
        final sublineWidth = _textWidth(subline!, sublineStyle);
        final fitsOnOneLine = sublineWidth + dotWidth + batteryWidth <= constraints.maxWidth;

        if (fitsOnOneLine) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(subline!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sublineStyle)),
              SizedBox(
                width: dotWidth,
                child: Text('·', textAlign: TextAlign.center, style: sublineStyle),
              ),
              _BatteryGroup(percent: batteryPercent!, textStyle: batteryTextStyle, disabled: disabled),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subline!, maxLines: 1, overflow: TextOverflow.ellipsis, style: sublineStyle),
            _BatteryGroup(percent: batteryPercent!, textStyle: batteryTextStyle, disabled: disabled),
          ],
        );
      },
    );
  }
}

double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

class _BatteryGroup extends StatelessWidget {
  const _BatteryGroup({required this.percent, required this.textStyle, required this.disabled});

  final int percent;
  final TextStyle textStyle;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? _disabledOpacity : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BatteryIcon(percent: percent),
          const SizedBox(width: 4),
          Text('$percent%', style: textStyle),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _spacingXs, vertical: _spacingXxs),
      decoration: BoxDecoration(color: _surfaceSuccess, borderRadius: BorderRadius.circular(_radiusPill)),
      child: Text(label, style: _textXs.copyWith(color: _textStandard)),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(_radiusStandard)),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(_radiusPill)),
    );
  }
}

/// Simple drawn battery glyph filled proportionally to [percent].
///
/// The Figma design only exports a "Battery-High" icon asset (no
/// low/medium variants), so the level is redrawn programmatically here
/// rather than swapping between exported assets.
class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _BatteryPainter(percent: percent.clamp(0, 100))),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter({required this.percent});

  final int percent;

  static const _bodyWidth = 18.0;
  static const _bodyHeight = 10.0;
  static const _capWidth = 2.0;
  static const _capHeight = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - _bodyWidth - _capWidth) / 2;
    final top = (size.height - _bodyHeight) / 2;

    final outline = Paint()
      ..color = _textStandard
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()
      ..color = _textStandard
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top, _bodyWidth, _bodyHeight), const Radius.circular(2)),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + _bodyWidth, top + (_bodyHeight - _capHeight) / 2, _capWidth, _capHeight),
        const Radius.circular(1),
      ),
      fill,
    );

    final fillWidth = (_bodyWidth - 4) * (percent / 100);
    if (fillWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 2, top + 2, fillWidth, _bodyHeight - 4),
          const Radius.circular(1),
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) => oldDelegate.percent != percent;
}

// Design tokens (from Figma "Equipment-Components" file, node 4837:19131).
const double _radiusStandard = 12;
const double _radiusSmall = 4;
const double _radiusPill = 999;
const double _spacingM = 16;
const double _spacingXs = 8;
const double _spacingXxs = 4;
const double _borderWidthStandard = 1;
const double _borderWidthFocus = 2;
const double _disabledOpacity = 0.4;
const Duration _skeletonPulseDuration = Duration(milliseconds: 1000);

const Color _surfaceStandard = Color(0xFFFFFFFF);
const Color _surfaceHovered = Color(0xFFEBEBEB);
const Color _surfacePressed = Color(0xFFD7D7D7);
const Color _surfaceSubdued = Color(0xFFF5F5F5);
const Color _surfaceSkeleton = Color(0xFFD7D7D7);
const Color _surfaceSkeletonPulse = Color(0xFFBDBDBD);
const Color _surfaceSelectedStandard = Color(0xFFEAF5FA);
const Color _surfaceSelectedHovered = Color(0xFFD5EBF6);
const Color _surfaceSelectedPressed = Color(0xFFA8D5EB);
const Color _surfaceSuccess = Color(0xFFAFE4C8);
const Color _borderSubdued = Color(0xFFEBEBEB);
const Color _borderFocused = Color(0xFF71A2FE);
const Color _textStandard = Color(0xFF242424);
const Color _textDisabled = Color(0xFF8A8A8A);

// Figma uses "Be Vietnam Pro"; not bundled here, so text falls back to the
// surrounding Theme's font family.
const TextStyle _textBaseStrong =
    TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, letterSpacing: -0.4);
const TextStyle _textBase =
    TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, letterSpacing: -0.4);
const TextStyle _textSmStrong =
    TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, letterSpacing: -0.35);
const TextStyle _textXs =
    TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w400, letterSpacing: -0.3);

const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x05000000), offset: Offset(0, 1), blurRadius: 0.5),
  BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 4),
];
