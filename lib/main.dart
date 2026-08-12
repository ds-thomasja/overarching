import 'package:flutter/material.dart';

import 'components/device_card/device_card.dart';

void main() {
  runApp(const ComponentPreviewApp());
}

class ComponentPreviewApp extends StatelessWidget {
  const ComponentPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overarching Component Preview',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const ComponentGalleryPage(),
    );
  }
}

class ComponentGalleryPage extends StatelessWidget {
  const ComponentGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Component Gallery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
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
              showOnlineTag: false,
              enabled: false,
            ),
            const DeviceCard(
              name: 'Loading device',
              isLoading: true,
            ),
          ],
        ),
      ),
    );
  }
}
