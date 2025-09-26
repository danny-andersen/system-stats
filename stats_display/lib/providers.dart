import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';

import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dropbox-api.dart';

part 'providers.g.dart';

const String nodeTemperatureFile = "/clusterNodesTemp.txt";

Color utilisationColor(value) {
  if (value == null) {
    return Colors.grey;
  } else if (value is String) {
    value = double.tryParse(value);
  }
  return value > 80
      ? Colors.red
      : (value > 60
          ? Colors.orange
          : (value > 40 ? Colors.amberAccent : Colors.green));
}

Color temperatureColor(value) {
  if (value == null) {
    return Colors.grey;
  } else if (value is String) {
    value = double.tryParse(value);
  }
  return value > 80
      ? Colors.red
      : (value > 60
          ? Colors.orange
          : (value > 40 ? Colors.amberAccent : Colors.blue));
}

class DateTimeNotifier extends StateNotifier<String> {
  late final Timer _timer;

  DateTimeNotifier() : super(_formattedNow()) {
    // Start a timer that updates the state every second
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      state = _formattedNow();
    });
  }

  static String _formattedNow() {
    return DateFormat('HH:mm:ss').format(DateTime.now());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

// Provider
final formattedDateTimeProvider =
    StateNotifierProvider<DateTimeNotifier, String>((ref) {
      return DateTimeNotifier();
    });

final systemListProvider = FutureProvider<List<(String, String)>>((ref) async {
  String oauthToken = "BLANK";

  final secret = await rootBundle.loadStructuredData<Secret>(
    'assets/api-key.json',
    (jsonStr) async {
      final secret = Secret.fromJson(jsonDecode(jsonStr));
      return secret;
    },
  );
  LocalSendReceive.username = secret.username;
  LocalSendReceive.passphrase = secret.password;
  LocalSendReceive.host = secret.controlHost;
  oauthToken = secret.apiKey;
  DropBoxAPIFn.globalOauthToken = oauthToken;
  // });

  final keyString = await rootBundle.loadString('assets/connect-data');
  LocalSendReceive.setKeys(keyString);

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

class Secret {
  final String apiKey;
  final String username;
  final String password;
  final String controlHost;
  Secret({
    this.apiKey = "",
    this.username = "",
    this.password = "",
    this.controlHost = "",
  });
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return Secret(
      apiKey: jsonMap["api_key"],
      username: jsonMap["username"],
      password: jsonMap["password"],
      controlHost: jsonMap["controlHost"],
    );
  }
}

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

void areWeOnLocalNetwork(Function callback) {
  bool found = false;
  NetworkInterface.list().then((interfaces) {
    for (NetworkInterface interface in interfaces) {
      for (InternetAddress addr in interface.addresses) {
        if (addr.address.contains('192.168.')) {
          found = true;
          // //On a private network
          // //Need to ping local thermostat to check we are on the same lan
          // Ping('thermostat-host', count: 1).stream.first
          //     .then((pingData) {
          //       if (pingData.error == null) {
          //         callback(true);
          //       } else {
          //         callback(false);
          //       }
          //     })
          //     .catchError((onError) {
          //       print(onError);
          //       callback(false);
          //     });
          callback(found);
          break;
        }
      }
      if (found) {
        break;
      }
    }
  });
}

class RelayStatus {
  RelayStatus({required this.onLocalLan});
  static const Map<String, int> hostToFanSpeed = {
    "pi4desktop": 3,
    "pi4node0": 2,
    "pi4node1": 1,
    "pi4node2": 0,
  };

  RelayStatus.fromParams(
    this.onLocalLan,
    this.localGetInProgress,
    this.oauthToken,
    this.lastUpdateTime,
    this.lastTempUpdateTime,
    this.nodeHosts,
    this.nodeTemperatures,
    this.fanSpeeds,
    this.actualRelayStates,
    this.requestedRelayStates,
  );

  RelayStatus copyWith({
    bool? localLan,
    bool? getInProgress,
    List<bool>? actualRelayStates,
    List<bool>? requestedRelayStates,
    DateTime? updateTime,
    DateTime? tempUpdateTime,
    List<String>? hosts,
    List<double>? temps,
    List<int>? speeds,
  }) {
    List<bool> newRelayStates = List<bool>.from(this.actualRelayStates);
    if (actualRelayStates != null && actualRelayStates.isNotEmpty) {
      for (int i = 0; i < actualRelayStates.length; i++) {
        if (actualRelayStates[i] != newRelayStates[i]) {
          newRelayStates[i] = actualRelayStates[i];
        }
      }
    }
    List<bool> newReqRelayStates = List<bool>.from(this.requestedRelayStates);
    if (requestedRelayStates != null && requestedRelayStates.isNotEmpty) {
      for (int i = 0; i < requestedRelayStates.length; i++) {
        if (requestedRelayStates[i] != newReqRelayStates[i]) {
          newReqRelayStates[i] = requestedRelayStates[i];
        }
      }
    }
    if (localLan != null) {
      onLocalLan = localLan;
    }
    if (getInProgress != null) {
      localGetInProgress = getInProgress;
    }
    if (updateTime != null) {
      lastUpdateTime = updateTime;
    }
    List<String> newNodes = List<String>.from(this.nodeHosts);
    if (hosts != null && hosts.isNotEmpty) {
      newNodes = hosts;
    }
    List<double> newTemps = List<double>.from(this.nodeTemperatures);
    if (temps != null && temps.isNotEmpty) {
      newTemps = temps;
    }
    List<int> newSpeeds = List<int>.from(this.fanSpeeds);
    if (speeds != null && speeds.isNotEmpty) {
      newSpeeds = speeds;
    }

    if (tempUpdateTime != null) {
      lastTempUpdateTime = tempUpdateTime;
    }
    return RelayStatus.fromParams(
      onLocalLan,
      localGetInProgress,
      oauthToken,
      lastUpdateTime,
      lastTempUpdateTime,
      newNodes,
      newTemps,
      newSpeeds,
      newRelayStates,
      newReqRelayStates,
    );
  }

  RelayStatus setRelayState({required int relayIndex, required bool state}) {
    List<bool> newReqRelayStates = List<bool>.from(requestedRelayStates);
    newReqRelayStates[relayIndex] = state;
    return copyWith(requestedRelayStates: newReqRelayStates);
  }

  late bool onLocalLan;
  bool localGetInProgress = false;
  String oauthToken = "";
  DateTime? lastUpdateTime;
  DateTime? lastTempUpdateTime;
  List<String> nodeHosts = [];
  List<double> nodeTemperatures = [];
  List<int> fanSpeeds = [];

  List<bool> actualRelayStates = [false, false, false, false, false, false];
  List<bool> requestedRelayStates = [false, false, false, false, false, false];
}

@riverpod
class RelayStatusNotifier extends _$RelayStatusNotifier {
  final String relayFile = "relay_status.txt";
  final String relayCommandFile = "relay_command.txt";
  final String localRelayStatusFile =
      "/home/danny/control_station/relay_status.txt";
  final String turnClusterOnSrc = "/home/danny/agent/cluster_on.txt";
  final String turnClusterOff = "bash /home/danny/agent/stopCluster.sh";

  @override
  RelayStatus build() {
    RelayStatus status = RelayStatus(onLocalLan: false);
    //Check if we are on local LAN
    areWeOnLocalNetwork((onlan) => status = status.copyWith(localLan: onlan));
    return status;
  }

  void refreshStatus() {
    if (state.onLocalLan) {
      getStatus();
    } else {
      areWeOnLocalNetwork((onlan) => state = state.copyWith(localLan: onlan));
    }
  }

  void setRelayState(int index, bool reqState) {
    state = state.setRelayState(relayIndex: index, state: reqState);
    //Send command to control station
    sendRelayCommandToHost(index: index, reqState: reqState);
  }

  void clusterOn(BuildContext context) {
    runSSHCommand(
      context,
      "Turn Cluster On",
      "cp $turnClusterOnSrc /home/danny/control_station/$relayCommandFile",
    );
  }

  void clusterOff(BuildContext context) {
    runSSHCommand(context, "Turn Cluster Off", turnClusterOff);
  }

  Future<void> runSSHCommand(
    BuildContext context,
    String question,
    String command,
  ) async {
    final confirmed = await _showConfirmationDialog(
      context,
      question,
      'Are you sure you want to do this?',
    );

    if (!confirmed) return;

    LocalSendReceive.runSSHCommand(command)
        .then((value) {
          if (value == null) {
            _showError(context, "Failed to run command");
          } else {
            _showMessage(context, value);
          }
        })
        .catchError((error) {
          _showError(context, error.toString());
        });
  }

  Future<bool> _showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('OK'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: Duration(seconds: 10)),
    );
  }

  void _showError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 10),
      ),
    );
  }

  void sendRelayCommandToHost({
    required int index,
    required bool reqState,
    bool dropboxOnly = false,
  }) {
    String contents = "${index + 1}=${reqState ? '1' : '0'}\n";
    bool onLocalLan = state.onLocalLan;
    if (!dropboxOnly && onLocalLan) {
      //Send command to control station
      Future<bool> localSend = LocalSendReceive.sendLocalFile(
        fileName: "/home/danny/control_station/$relayCommandFile",
        contents: contents,
        append: true,
      );
      localSend.then((success) {
        if (!success) {
          print("On local Lan but failed to send command file");
          // sendRelayCommandToHost(
          //   index: index,
          //   reqState: reqState,
          //   dropboxOnly: true,
          // );
        }
      });
    } else {
      //Remote from control station - use Dropbox to send command
      DropBoxAPIFn.sendDropBoxFile(
        // oauthToken: state.oauthToken,
        fileToUpload: "/$relayCommandFile",
        contents: contents,
        append: true,
      );
    }
  }

  void getStatus({bool dropboxOnly = false}) {
    bool localRead = false;
    if (!state.localGetInProgress) {
      //Use ftp to retrieve status file direct from control station
      Future<Map<String, String>> localReceive = LocalSendReceive.getLocalFile([
        localRelayStatusFile,
      ]);
      state = state.copyWith(getInProgress: true);
      localReceive.then((files) {
        bool success = false;
        state = state.copyWith(getInProgress: false);
        if (files.containsKey(localRelayStatusFile)) {
          String? statusStr = files[localRelayStatusFile];
          if (statusStr != null) {
            processRelayStateFile(localRelayStatusFile, statusStr);
            success = true;
          }
        }
        if (!success) {
          print("Failed to get status file from thermostat-host");
        }
      });
    } else {
      print("getStatus(): Get already in progress");
    }
    // Now get cluster node temp file sent by the fan controller
    DropBoxAPIFn.getDropBoxFile(
      // oauthToken: state.oauthToken,
      fileToDownload: nodeTemperatureFile,
      callback: processNodeTempFile,
      contentType: ContentType.text,
      timeoutSecs: 1, //Cache entry timeout
    );
  }

  void processRelayStateFile(String filename, String contents) {
    if (contents.isEmpty || contents.contains("error")) {
      return;
    }
    try {
      List<String> parts = contents.split('@');
      if (parts.length < 2) {
        print("Received invalid relay state format: $contents");
        return;
      }
      String dateStr = parts[0].trim();
      DateTime newLastHeard = DateTime.parse(dateStr);
      int relayState = int.parse(parts[1].trim());
      List<bool> newRelayStates = [false, false, false, false, false, false];
      if (relayState & 1 == 1) {
        newRelayStates[0] = true;
      }
      if (relayState & 2 == 2) {
        newRelayStates[1] = true;
      }
      if (relayState & 4 == 4) {
        newRelayStates[2] = true;
      }
      if (relayState & 8 == 8) {
        newRelayStates[3] = true;
      }
      if (relayState & 0x10 == 0x10) {
        newRelayStates[4] = true;
      }
      if (relayState & 0x20 == 0x20) {
        newRelayStates[5] = true;
      }
      state = state.copyWith(
        updateTime: newLastHeard,
        actualRelayStates: newRelayStates,
      );
    } on FormatException {
      print("Received non-int relay state format or timestamp: $contents");
    }
  }

  void processNodeTempFile(String filename, String contents) {
    //Format is <data time>={<hostname>:<temp>}]}
    if (contents.isEmpty || contents.contains("error")) {
      return;
    }
    try {
      // print("Received node temp file: $contents");
      List<String> parts = contents.split('@');
      String dateStr = parts[0].trim();
      dateStr = dateStr.replaceAll('/', '-');
      DateTime newLastHeard = DateTime.parse(dateStr);
      DateTime now = DateTime.now();
      if (newLastHeard.isBefore(now.subtract(Duration(minutes: 3)))) {
        //Ignore old data
        state = state.copyWith(tempUpdateTime: newLastHeard);
      } else {
        String nodeStr = parts[1].trim();
        nodeStr = nodeStr.replaceAll("'", '"');
        Map<String, dynamic> tempData = jsonDecode(nodeStr);
        List<dynamic> fanData = [];
        if (parts.length == 3) {
          //Parse fan speeds
          fanData = jsonDecode(parts[2]);
        }
        List<String> newNodes = [];
        List<double> newTemps = [];
        List<int> fanSpeeds = [];
        for (String key in tempData.keys) {
          var t = tempData[key];
          double temp = double.parse(t.toString());
          newNodes.add(key);
          newTemps.add(temp);
          if (fanData.isNotEmpty) {
            if (RelayStatus.hostToFanSpeed[key] != null) {
              int fanIndex = RelayStatus.hostToFanSpeed[key]!;
              int fanSpeed = fanData[fanIndex];
              fanSpeeds.add(fanSpeed);
            }
          }
        }
        state = state.copyWith(
          tempUpdateTime: newLastHeard,
          hosts: newNodes,
          temps: newTemps,
          speeds: fanSpeeds,
        );
      }
    } on FormatException catch (e) {
      print(
        "Received invalid node and temp or timestamp: $contents: Error: $e",
      );
    }
  }
}
