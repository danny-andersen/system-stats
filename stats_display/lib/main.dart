import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:stats_display/detailed_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: SystemMonitorApp()));
}

final systemListProvider = FutureProvider<List<(String, String)>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/systems.json');
  final List<dynamic> data = json.decode(jsonString);
  final List<String> systemList = data.cast<String>();
  List<(String, String)> systems = [];
  for (String system in systemList) {
    List<String> entry = system.split(',');
    final systemName = entry[0].trim();
    final systemUrl = entry[1].trim();
    systems.add((systemName, systemUrl));
  }
  return systems;
});

// final systemListProvider = Provider<List<(String, String)>>(
//   (ref) => [
//     ('gaming-pc-ubuntu', 'http://192.168.1.232:5000/stats'),
//     ('system-1', 'http://system1.local/status'),
//     ('system-2', 'http://system2.local/status'),
//   ],
// );

final selectedSystemProvider = StateProvider<(String, String)?>((ref) => null);

final systemInfoNotifierProvider = StateNotifierProvider.autoDispose.family<
  SystemInfoNotifier,
  AsyncValue<Map<String, dynamic>>,
  (String, String)
>((ref, system) {
  return SystemInfoNotifier(system);
});

class SystemInfoNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final (String, String) system;
  bool disposed = false;
  Timer? _timer;

  SystemInfoNotifier(this.system) : super(AsyncLoading()) {
    _fetchData();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse(system.$2));
      if (!disposed) {
        //Widget may have been disposed whilst waiting for a response
        if (response.statusCode == 200) {
          state = AsyncData(json.decode(response.body));
        } else {
          state = AsyncError('Failed to load system data', StackTrace.current);
        }
      }
    } catch (e) {
      if (!disposed) {
        state = AsyncError(e, StackTrace.current);
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    _timer?.cancel();
    super.dispose();
  }
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
      appBar: AppBar(title: Text('Systems Overview')),
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

        return ListTile(
          title: Text(
            systemName,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'CPU: ${cpuUsage.toStringAsFixed(1)}%, GPU: ${gpuUsage != null ? gpuUsage.toStringAsFixed(1) : 'N/A'}%, CPU Temp: ${cpuTemp.toStringAsFixed(1)}°C, Mem: ${memoryUsage.toStringAsFixed(1)}%',
          ),
          onTap:
              () =>
                  ref.read(selectedSystemProvider.notifier).state = (
                    systemName,
                    systemUrl,
                  ),
        );
      },
      loading:
          () => ListTile(
            title: Text(
              systemName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Loading...'),
          ),
      error:
          (err, stack) => ListTile(
            title: Text(
              systemName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Error: $err'),
          ),
    );
  }
}
