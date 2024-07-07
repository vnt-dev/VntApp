import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

import '../vnt/vnt_manager.dart';
import 'legend_widget.dart';

class StatisticsChart extends StatefulWidget {
  final VntBox vntBox;

  const StatisticsChart({
    super.key,
    required this.vntBox,
  });
  final Color leftBarColor = const Color.fromARGB(255, 253, 104, 58);
  final Color rightBarColor = const Color.fromARGB(255, 59, 255, 73);
  @override
  State<StatefulWidget> createState() => StatisticsChartState();
}

class StatisticsChartState extends State<StatisticsChart> {
  final double width = 7;
  late double max = 0;
  final height = 50;
  StatisticsChartState();
  int touchedGroupIndex = -1;
  bool showB = false;
  Uint64List upList = Uint64List(0);
  double lineMax = 0;
  Uint64List downList = Uint64List(0);
  List<(String, BigInt, BigInt)> barChartDataList = [];
  String uploadTotal = '';
  String downloadTotal = '';
  double maxY = 0;
  String ip = '';
  String ipUpload = '';
  String ipDownload = '';

  @override
  void initState() {
    super.initState();
  }

  void updateBarChart() {
    showB = false;
    _updateBarChart();
  }

  void _updateBarChart() {
    barChartDataList = widget.vntBox.vntApi.streamAll();
    uploadTotal = widget.vntBox.upStream();
    downloadTotal = widget.vntBox.downStream();
    for (var item in barChartDataList) {
      var leftY = item.$2.toDouble();
      var rightY = item.$3.toDouble();
      if (leftY > maxY) {
        maxY = leftY;
      }
      if (rightY > maxY) {
        maxY = rightY;
      }
    }
    if (maxY < 1) {
      maxY = 1;
    }
    setState(() {});
  }

  void _updateLineChart() {
    _chartBData(touchedGroupIndex);
  }

  void updateData() {
    if (showB) {
      _updateLineChart();
    } else {
      _updateBarChart();
    }
  }

  void _chartBData(int index) {
    ip = barChartDataList[index].$1;
    upList = widget.vntBox.vntApi.upStreamLine(ip: ip);
    downList = widget.vntBox.vntApi.downStreamLine(ip: ip);
    ipUpload = widget.vntBox.vntApi.ipUpStreamTotal(ip: ip);
    ipDownload = widget.vntBox.vntApi.ipDownStreamTotal(ip: ip);
    var lineMaxTmp = 0.0;
    for (var item in upList) {
      var tmp = item.toDouble();
      if (tmp > lineMaxTmp) {
        lineMaxTmp = tmp;
      }
    }
    for (var item in downList) {
      var tmp = item.toDouble();
      if (tmp > lineMaxTmp) {
        lineMaxTmp = tmp;
      }
    }
    lineMaxTmp += lineMaxTmp * 0.05;

    setState(() {
      upList = upList;
      downList = downList;
      lineMax = lineMaxTmp;
      showB = true;
    });
  }

  Widget _chartB() {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          width: constraints.maxWidth,
          child: AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        LegendsListWidget(
                          legends: [
                            Legend('上传', widget.leftBarColor),
                            Legend('下载', widget.rightBarColor),
                          ],
                        ),
                        const SizedBox(
                          width: 16,
                        ),
                        Text(
                          'IP: $ip',
                          style: const TextStyle(
                              color: Color(0xff77839a), fontSize: 16),
                        ),
                      ],
                    ),
                    Text(
                      '总上传: $ipUpload',
                      style: const TextStyle(
                          color: Color(0xff77839a), fontSize: 16),
                    ),
                    Text(
                      '总下载: $ipDownload',
                      style: const TextStyle(
                          color: Color(0xff77839a), fontSize: 16),
                    ),
                    const SizedBox(
                      height: 38,
                    ),
                    Expanded(
                      child: LineChart(mainData()),
                    ),
                  ],
                ),
              )));
    });
  }

  Widget _scrollCartA() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: barChartDataList.length * 140.0 > constraints.maxWidth
                ? barChartDataList.length * 140.0
                : constraints.maxWidth,
            child: AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _chartA(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chartA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LegendsListWidget(
              legends: [
                Legend('上传', widget.leftBarColor),
                Legend('下载', widget.rightBarColor),
              ],
            ),
            const SizedBox(
              width: 16,
            ),
          ],
        ),
        Text(
          '总上传: $uploadTotal',
          style: const TextStyle(color: Color(0xff77839a), fontSize: 16),
        ),
        Text(
          '总下载: $downloadTotal',
          style: const TextStyle(color: Color(0xff77839a), fontSize: 16),
        ),
        const SizedBox(
          height: 38,
        ),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: ((group) {
                    return Colors.grey;
                  }),
                  getTooltipItem: (a, b, c, d) => null,
                ),
                touchCallback: (FlTouchEvent event, barTouchResponse) {
                  if (event is FlTapUpEvent) {
                    setState(() {
                      if (barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        touchedGroupIndex = -1;
                        return;
                      }
                      touchedGroupIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });

                    if (touchedGroupIndex != -1) {
                      // 在这里处理点击事件
                      _chartBData(touchedGroupIndex);
                    }
                  }
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: bottomTitles,
                    reservedSize: 42,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: false,
              ),
              barGroups: barChartDataList.asMap().entries.map((item) {
                var leftY = item.value.$2.toDouble();
                var rightY = item.value.$3.toDouble();
                return makeGroupData(item.key, leftY, rightY);
              }).toList(),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
        const SizedBox(
          height: 12,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return showB ? _chartB() : _scrollCartA();
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    final Widget text = Text(
      barChartDataList[value.toInt()].$1,
      style: const TextStyle(
        color: Color(0xff7589a2),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 16, //margin top
      child: text,
    );
  }

  BarChartGroupData makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(
      barsSpace: 4,
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: widget.leftBarColor,
          width: width,
        ),
        BarChartRodData(
          toY: y2,
          color: widget.rightBarColor,
          width: width,
        ),
      ],
    );
  }

  LineChartData mainData() {
    return LineChartData(
      // gridData: FlGridData(
      //   show: true,
      //   // drawVerticalLine: true,
      //   getDrawingHorizontalLine: (value) {
      //     return const FlLine(
      //       color: Color(0xff77839a),
      //       // strokeWidth: 1,
      //     );
      //   },
      //   getDrawingVerticalLine: (value) {
      //     return const FlLine(
      //       color: Color(0xff77839a),
      //       strokeWidth: 1,
      //     );
      //   },
      // ),
      titlesData: const FlTitlesData(
        show: true,
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
          ),
        ),
        // leftTitles: AxisTitles(
        //   sideTitles: SideTitles(
        //     showTitles: true,
        //     interval: 1,
        //     getTitlesWidget: leftTitleWidgets,
        //     reservedSize: 42,
        //   ),
        // ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: 0,
      maxX: 100,
      minY: 0,
      maxY: lineMax,
      lineBarsData: [
        LineChartBarData(
          color: widget.leftBarColor,
          spots: upList.asMap().entries.map((item) {
            return FlSpot(item.key.toDouble(), item.value.toDouble());
          }).toList(),
          // isCurved: true,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
          ),
        ),
        LineChartBarData(
          color: widget.rightBarColor,
          spots: downList.asMap().entries.map((item) {
            return FlSpot(item.key.toDouble(), item.value.toDouble());
          }).toList(),
          // isCurved: true,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
          ),
        ),
      ],
    );
  }
}
