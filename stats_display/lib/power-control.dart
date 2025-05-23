import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class RelayControlPage extends ConsumerStatefulWidget {
  RelayControlPage({super.key});
  late _RelayControlPageState statePage;

  @override
  ConsumerState<RelayControlPage> createState() {
    statePage = _RelayControlPageState();
    return statePage;
  }
}

class _RelayControlPageState extends ConsumerState<RelayControlPage> {
  _RelayControlPageState();

  List<String> socket = [
    'pi4desktop ',
    'pi4node0   ',
    'pi4node1   ',
    'pi4node2   ',
    'Fans         ',
    'Network SW ',
  ];
  late Timer timer;
  DateTime? lastCommandTime;

  @override
  void initState() {
    //Trigger first refresh shortly after widget initialised, to allow state to be initialised
    timer = Timer(const Duration(seconds: 1), updateStatus);
    super.initState();
  }

  int getRefreshTimerDurationMs() {
    //If local UI refresh quickly to immediate feedback
    //If on Local lan can get files quickly directly from control station, unless there is an issue
    //e.g. request is hanging, in which case get from dropbox less frequently
    final provider = ref.read(relayStatusNotifierProvider);
    if (lastCommandTime != null && !provider.localGetInProgress) {
      final diff = DateTime.now().difference(lastCommandTime!).inSeconds;
      if (diff < 60) {
        //We have just sent a command, so refresh quickly
        return 2000;
      }
    }
    return provider.onLocalLan && !provider.localGetInProgress ? 5000 : 10000;
  }

  void updateStatus() {
    //Note: Set timer before we call refresh otherwise will always have a get in progress
    timer = Timer(
      Duration(milliseconds: getRefreshTimerDurationMs()),
      updateStatus,
    );
    ref.read(relayStatusNotifierProvider.notifier).refreshStatus();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void setRelayState(int index, bool state) {
    lastCommandTime = DateTime.now();
    ref.read(relayStatusNotifierProvider.notifier).setRelayState(index, state);
  }

  void fetchRelayStates() {
    ref.read(relayStatusNotifierProvider.notifier).refreshStatus();
  }

  static const WidgetStateProperty<Icon> thumbIcon =
      WidgetStateProperty<Icon>.fromMap(<WidgetStatesConstraint, Icon>{
        WidgetState.selected: Icon(Icons.power, color: Colors.green),
        WidgetState.any: Icon(Icons.power_off, color: Colors.red),
      });

  @override
  Widget build(BuildContext context) {
    final RelayStatus status = ref.watch(relayStatusNotifierProvider);
    Color txtColor = Colors.green;
    String lastHeardStr = "??";
    if (status.lastUpdateTime == null) {
      txtColor = Colors.red;
      lastHeardStr = "Never";
    } else {
      DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
      lastHeardStr = formatter.format(status.lastUpdateTime!);
      DateTime currentTime = DateTime.now();
      int timezoneDifference = currentTime.timeZoneOffset.inMinutes;
      if (currentTime.timeZoneName == 'BST' ||
          currentTime.timeZoneName == 'GMT') {
        timezoneDifference = 0;
      }
      int diff =
          currentTime.difference(status.lastUpdateTime!).inMinutes -
          timezoneDifference;
      if (diff == 60) {
        //If exactly 60 mins then could be daylight savings
        diff = 0;
      }
      if (diff > 15) {
        txtColor = Colors.red;
      } else if (diff > 5) {
        txtColor = Colors.amber;
      } else {
        txtColor = Colors.green;
      }
    }
    Color txtColorTemp = Colors.green;
    String lastHeardStrTemp = "??";
    if (status.lastTempUpdateTime == null) {
      txtColorTemp = Colors.red;
    } else {
      DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
      lastHeardStrTemp = formatter.format(status.lastTempUpdateTime!);
      DateTime currentTime = DateTime.now();
      int timezoneDifference = currentTime.timeZoneOffset.inMinutes;
      if (currentTime.timeZoneName == 'BST' ||
          currentTime.timeZoneName == 'GMT') {
        timezoneDifference = 0;
      }
      int diff =
          currentTime.difference(status.lastTempUpdateTime!).inMinutes -
          timezoneDifference;
      if (diff == 60) {
        //If exactly 60 mins then could be daylight savings
        diff = 0;
      }
      if (diff > 15) {
        txtColorTemp = Colors.red;
      } else if (diff > 5) {
        txtColorTemp = Colors.amber;
      } else {
        txtColorTemp = Colors.green;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Last Update: $lastHeardStr',
          style: TextStyle(color: txtColor, fontSize: 16),
        ),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: fetchRelayStates),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(5.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Relay',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Req State',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Actual State',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Controls',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Divider(),
            ...List.generate(6, (index) {
              return Row(
                children: [
                  Expanded(
                    child: Center(child: Text('${index + 1} ${socket[index]}')),
                  ),
                  Expanded(
                    child: Center(
                      child: Icon(
                        status.requestedRelayStates[index]
                            ? Icons.power
                            : Icons.power_off,
                        color:
                            status.requestedRelayStates[index]
                                ? Colors.green
                                : Colors.red,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Align(
                        alignment: Alignment.center,
                        child: Icon(
                          status.actualRelayStates[index]
                              ? Icons.check_circle
                              : Icons.cancel,
                          color:
                              status.actualRelayStates[index]
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Align(
                        alignment: Alignment.center,
                        child: Switch(
                          value: status.actualRelayStates[index],
                          activeColor: Colors.green,
                          thumbIcon: thumbIcon,
                          onChanged: (bool val) => setRelayState(index, val),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 50),
                ],
              );
            }),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed:
                      () => ref
                          .read(relayStatusNotifierProvider.notifier)
                          .clusterOn(context),
                  child: const Text('Cluster ON'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed:
                      () => ref
                          .read(relayStatusNotifierProvider.notifier)
                          .clusterOff(context),
                  child: const Text('Cluster OFF'),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              '  Last Node Temperature Update: $lastHeardStrTemp',
              style: TextStyle(color: txtColorTemp, fontSize: 15),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Host',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'CPU Temp',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Fan Speed',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Divider(),
            ...List.generate(status.nodeHosts.length, (index) {
              return Row(
                children: [
                  Expanded(child: Center(child: Text(status.nodeHosts[index]))),
                  Expanded(
                    child: Center(
                      child: Text(status.nodeTemperatures[index].toString()),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        status.fanSpeeds.length <= index
                            ? "?"
                            : status.fanSpeeds[index] == 255
                            ? 'N/A'
                            : status.fanSpeeds[index] == 0
                            ? "Off"
                            : "${status.fanSpeeds[index].toString()}%",
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
