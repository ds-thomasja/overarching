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

/// Renders every migrated component in a few representative states so they
/// can be verified visually in the browser.
class ComponentGalleryPage extends StatelessWidget {
  const ComponentGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.background.standard,
      appBar: AppBar(title: const Text('Component Gallery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spacing.layout.l),
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
                status: DeviceCardStatus.offline,
                enabled: false,
              ),
              const DeviceCard(
                name: 'Loading device',
                isLoading: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
