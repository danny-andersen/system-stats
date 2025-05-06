import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
      final response = await http.get(Uri.parse("${system.$2}/minstats"));
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

final systemDetailNotifierProvider = StateNotifierProvider.autoDispose
    .family<SystemDetailNotifier, AsyncValue<Map<String, dynamic>>, String>((
      ref,
      systemUrl,
    ) {
      return SystemDetailNotifier(systemUrl);
    });

class SystemDetailNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final String systemUrl;
  bool disposed = false;
  Timer? _timer;

  SystemDetailNotifier(this.systemUrl) : super(AsyncLoading()) {
    _fetchData();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse("$systemUrl/fullstats"));
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
