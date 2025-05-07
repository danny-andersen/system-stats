import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stats_display/detailed_screen.dart';
import 'package:stats_display/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: SystemMonitorApp()));
}

class SystemMonitorApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSystem = ref.watch(selectedSystemProvider);
    return MaterialApp(
      // title: 'System Monitor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home:
          selectedSystem == null
              ? SystemListScreen()
              : SystemInfoScreen(
                systemName: selectedSystem.$1,
                systemUrl: selectedSystem.$2,
                selectedSystemProvider: selectedSystemProvider,
              ),
    );
  }
}

class SystemListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemsAsync = ref.watch(systemListProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Systems Status Overview')),
      body: systemsAsync.when(
        data:
            (systems) => ListView.builder(
              itemCount: systems.length,
              itemBuilder: (context, index) {
                final (systemName, systemUrl) = systems[index];
                return ProviderScope(
                  overrides: [_localSystemUrl.overrideWithValue(systemUrl)],
                  child: SystemListTile(
                    systemName: systemName,
                    systemUrl: systemUrl,
                  ),
                );
              },
            ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load systems: $err')),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Drawer Header'),
            ),
            ListTile(
              title: const Text('Item 1'),
              onTap: () {
                // Update the state of the app.
                // ...
              },
            ),
            ListTile(
              title: const Text('Item 2'),
              onTap: () {
                // Update the state of the app.
                // ...
              },
            ),
          ],
        ),
      ),
    );
  }
}

final _localSystemUrl = Provider<String>((ref) => throw UnimplementedError());

class SystemListTile extends ConsumerWidget {
  final String systemUrl;
  final String systemName;
  const SystemListTile({required this.systemName, required this.systemUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(
      systemInfoNotifierProvider((systemName, systemUrl)),
    );

    return asyncData.when(
      data: (data) {
        final cpuUsage = data["cpu"]["usage_percent"];
        final cpuTemp = data["temperature"]["cpu"];
        final memoryUsage = data["memory"]["usage_percent"];
        final gpuUsage =
            data["gpu"].isNotEmpty
                ? (data["gpu"][0]["utilization_percent"])
                : null;
        final gpuTemp =
            data["gpu"].isNotEmpty
                ? data["gpu"][0]["temperature_C"] * 1.0
                : null;

        return Card(
          child: ListTile(
            // contentPadding: EdgeInsets.only({5.0}),
            title: Text(
              systemName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              spacing: 5,
              children: [
                Text(
                  'CPU: ${cpuUsage.toStringAsFixed(1)}%',
                  style: TextStyle(color: utilisationColor(cpuUsage)),
                ),
                Text(
                  'CPU Temp: ${cpuTemp.toStringAsFixed(1)}°C',
                  style: TextStyle(color: temperatureColor(cpuTemp)),
                ),
                Text(
                  'Mem: ${memoryUsage.toStringAsFixed(1)}%',
                  style: TextStyle(color: utilisationColor(memoryUsage)),
                ),
                Text(
                  'GPU: ${gpuUsage != null ? gpuUsage.toStringAsFixed(1) : 'N/A'}%',
                  style: TextStyle(color: utilisationColor(gpuUsage)),
                ),
                Text(
                  'GPU Temp: ${gpuTemp != null ? gpuTemp.toStringAsFixed(1) : 'N/A'}°C',
                  style: TextStyle(color: temperatureColor(gpuTemp)),
                ),
              ],
            ),
            onTap:
                () =>
                    ref.read(selectedSystemProvider.notifier).state = (
                      systemName,
                      systemUrl,
                    ),
          ),
        );
      },
      loading:
          () => Card(
            child: ListTile(
              title: Text(
                systemName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Loading...'),
            ),
          ),
      error:
          (err, stack) => Card(
            child: ListTile(
              title: Text(
                systemName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle:
                  err.toString().contains("No route to host")
                      ? Text("Unavailable")
                      : ((err.toString().contains("Connection timed out") ||
                              err.toString().contains("Connection refused"))
                          ? Text("Agent service not running")
                          : Text('Error: $err')),
            ),
          ),
    );
  }
}
