import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stats_display/providers.dart';

class SystemInfoScreen extends ConsumerWidget {
  final String systemUrl;
  final String systemName;
  final selectedSystemProvider;
  const SystemInfoScreen({
    required this.systemName,
    required this.systemUrl,
    required this.selectedSystemProvider,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSystemData = ref.watch(systemDetailNotifierProvider(systemUrl));
    final dateTime = ref.watch(formattedDateTimeProvider);

    // final screenSize = MediaQuery.of(context).size;
    final graphHeightByValue = 45.0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 35,
        title: Text('$systemName $dateTime', style: TextStyle(fontSize: 15)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed:
              () => ref.read(selectedSystemProvider.notifier).state = null,
        ),
      ),
      body: asyncSystemData.when(
        data: (data) {
          List<String> utilLabels = ['cpu', 'mem'];
          List<double> utilValues = [
            data["cpu"]["usage_percent"],
            data["memory"]["usage_percent"],
          ];
          if ((data["gpu"] as List).isNotEmpty) {
            utilLabels.addAll(['gpu', 'mem']);
            utilValues.addAll([
              data["gpu"][0]["utilization_percent"] * 1.0,
              data["gpu"][0]["memory_used_MB"] /
                  data["gpu"][0]["memory_total_MB"] *
                  100.0,
            ]);
          } else {
            utilLabels.add('disk');
            utilValues.add(data["disk"]["usage_percent"]);
          }
          if (data.containsKey("swap") && data["swap"]["usage_percent"] != 0) {
            utilLabels.add('swap');
            utilValues.add(data["swap"]["usage_percent"]);
          }

          List<String> tempLabels = data["temperature"].keys.toList();
          List<double> tempValues =
              data["temperature"].values.toList().cast<double>();
          if (data["gpu"].isNotEmpty) {
            tempValues.insert(0, data["gpu"][0]["temperature_C"] * 1.0);
            tempLabels.insert(0, 'gpu');
          }
          double tempGraphHeight =
              data["temperature"].length * graphHeightByValue;

          return ListView(
            children: [
              buildInfoSection('Utilisation %', [
                multiBarGraph(
                  height: graphHeightByValue * utilValues.length,
                  labels: utilLabels,
                  values: utilValues,
                  dynamicColor: utilisationColor,
                  unit: '%',
                ),
              ]),
              buildInfoSection('Temperatures °C', [
                multiBarGraph(
                  height: tempGraphHeight,
                  labels: tempLabels,
                  values: tempValues,
                  dynamicColor: temperatureColor,
                  unit: '°C',
                ),
              ]),
              buildInfoSection('Detailed Stats', [
                Text('CPU Count: ${data["cpu"]["cpu_count"]}'),
                Text('CPU Frequency: ${data["cpu"]["cpu_freq"]} MHz'),
                Row(
                  spacing: 10.0,
                  children: [
                    Text('DRAM: ${data["memory"]["total_gb"]} GB'),
                    Text('Used: ${data["memory"]["used_gb"]} GB'),
                    Text('Free: ${data["memory"]["free_gb"]} GB'),
                  ],
                ),
                data.containsKey("swap")
                    ? Row(
                      spacing: 10.0,
                      children: [
                        Text('Swap: ${data["swap"]["total_gb"]} GB'),
                        Text('Used: ${data["swap"]["used_gb"]} GB'),
                        Text('Free: ${data["swap"]["free_gb"]} GB'),
                      ],
                    )
                    : const SizedBox.shrink(),
                data["gpu"].isNotEmpty
                    ? Row(
                      spacing: 10.0,
                      children: [
                        Text(
                          'GPU Memory: ${((data["gpu"][0]["memory_total_MB"]) / 1024.0).toStringAsPrecision(2)} GB',
                        ),
                        Text(
                          'Used: ${((data["gpu"][0]["memory_used_MB"]) / 1024.0).toStringAsPrecision(2)} GB',
                        ),
                      ],
                    )
                    : Text("No GPU Detected"),
                Row(
                  spacing: 5.0,
                  children: [
                    Text('Main Disk: ${data["disk"]["total_gb"]} GB'),
                    Text('Used: ${data["disk"]["used_gb"]} GB'),
                    Text('Free: ${data["disk"]["free_gb"]} GB'),
                  ],
                ),
                SizedBox(height: 5),
                Text('Uptime: ${data["uptime"]}'),
                Text('Last Boot: ${data["boot_time"]}'),
              ]),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget buildInfoSection(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget multiBarGraph({
    required height,
    required List<String> labels,
    required List<double> values,
    required Color Function(double) dynamicColor,
    required String unit,
  }) {
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              (unit == '%')
                  ? 100
                  : (unit == '°C')
                  ? 100
                  : null,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: unit == '%' ? 20 : null,
                reservedSize: 28,
                getTitlesWidget:
                    (value, meta) => Text(
                      '${value.toInt()}$unit',
                      style: TextStyle(fontSize: 10),
                    ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  return index < labels.length
                      ? Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          labels[index],
                          style: TextStyle(fontSize: 10),
                        ),
                      )
                      : Text('');
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          rotationQuarterTurns: 1,

          barGroups:
              values.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      color: dynamicColor(value),
                      width: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget barGraph(List<double> values, Color color, String unit) {
    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 10,
                reservedSize: 28,
                getTitlesWidget:
                    (value, meta) => Text(
                      '${value.toInt()}$unit',
                      style: TextStyle(fontSize: 10),
                    ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget:
                    (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${value.toInt()}',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          rotationQuarterTurns: 1,
          barGroups:
              values.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      color: color,
                      width: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }
}
