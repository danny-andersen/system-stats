import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:process_run/shell.dart';

import 'package:stats_display/detailed_screen.dart';
import 'package:stats_display/providers.dart';
import 'package:stats_display/power-control.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check hostname
  final hostnameResult = await Process.run('hostname', []);
  final hostname = hostnameResult.stdout.toString().trim();

  // Set brightness based on hostname
  final isPizero = hostname == 'pizero-lcd';

  runApp((ProviderScope(child: SystemMonitorApp(isOnLCD: isPizero))));
}

class SystemMonitorApp extends ConsumerWidget {
  final bool isOnLCD;
  const SystemMonitorApp({super.key, required this.isOnLCD});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSystem = ref.watch(selectedSystemProvider);

    return MaterialApp(
      // title: 'System Monitor',
      // theme: ThemeData(primarySwatch: Colors.blue),
      theme: ThemeData(
        useMaterial3: true,

        // Define the default brightness and colors.
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: isOnLCD ? Brightness.light : Brightness.dark,
        ), // This is the theme of your application.
        // primarySwatch: Colors.blue,
        // fontFamily: 'Roboto',
      ),
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
  Future<void> _shutdownSystem(BuildContext context) async {
    // Get hostname
    final hostnameResult = await Process.run('hostname', []);
    final hostname = hostnameResult.stdout.toString().trim();

    if (hostname != 'pizero-lcd') {
      _showError(
        context,
        'This command can only run on device: pizero-lcd\nDetected: $hostname',
      );
      return;
    }

    // // Run shutdown
    // final result = await Process.run('sudo shutdown', [
    //   '-h',
    //   'now',
    //   '--no-wall',
    // ]);

    final shell = Shell();

    try {
      await shell.run('sudo shutdown -h now --no-wall');
    } catch (e) {
      _showError(context, 'Shutdown failed: $e');
    }
    //   if (result.exitCode == 0) {
    //     print('Shutdown command executed successfully');
    //   } else {
    //     print('Shutdown failed: ${result.stderr}');
    //     _showError(context, result.stderr.toString());
    //   }
    // } catch (e) {
    //   print('Error: $e');
    //   _showError(context, e.toString());
    // }
  }

  void _showError(BuildContext context, String error) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Error'),
            content: Text(error),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemsAsync = ref.watch(systemListProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Systems Status Overview'), toolbarHeight: 35),
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
              title: const Text('Power Controller'),
              onTap: () {
                // Navigate to Power controller screen.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RelayControlPage()),
                );
              },
            ),
            ListTile(
              title: const Text('Shutdown'),
              onTap: () => _shutdownSystem(context),
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
        final swapUsage =
            data.containsKey("swap") ? data["swap"]["usage_percent"] : 0;
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
                  '(${cpuTemp.toStringAsFixed(1)}°C)',
                  style: TextStyle(color: temperatureColor(cpuTemp)),
                ),
                Text(
                  'Mem: ${memoryUsage.toStringAsFixed(1)}%',
                  style: TextStyle(color: utilisationColor(memoryUsage)),
                ),
                swapUsage != 0
                    ? Text(
                      'Swap: ${swapUsage.toStringAsFixed(1)}%',
                      style: TextStyle(color: utilisationColor(swapUsage)),
                    )
                    : const SizedBox.shrink(),
                gpuUsage != null
                    ? Text(
                      'GPU: ${gpuUsage.toStringAsFixed(1)}%',
                      style: TextStyle(color: utilisationColor(gpuUsage)),
                    )
                    : const SizedBox.shrink(),
                gpuUsage != null
                    ? Text(
                      '(${gpuTemp.toStringAsFixed(1)}°C)',
                      style: TextStyle(color: temperatureColor(gpuTemp)),
                    )
                    : const SizedBox.shrink(),
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
