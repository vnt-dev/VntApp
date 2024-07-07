import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'connect_log.dart';
import 'network_config.dart';
import 'custom_app_bar.dart';
import 'src/rust/api/vnt_api.dart';
import 'package:json2yaml/json2yaml.dart';

import 'vnt/vnt_manager.dart';
import 'widgets/dual_bar_chart.dart';

class ConnectDetailPage extends StatefulWidget {
  final NetworkConfig config;
  final VntBox vntBox;

  const ConnectDetailPage(
      {super.key, required this.config, required this.vntBox});

  @override
  _ConnectDetailPageState createState() => _ConnectDetailPageState();
}

class _ConnectDetailPageState extends State<ConnectDetailPage> {
  final GlobalKey<StatisticsChartState> _keyChart =
      GlobalKey<StatisticsChartState>();

  int _selectedIndex = 0;
  List<Map<String, String>> deviceList = [];
  List<Map<String, String>> routeList = [];
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _loadData(false);
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      _loadData(true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 取消定时器以防止内存泄漏
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _loadData(false);
    });
  }

  Future<void> _loadData(bool timer) async {
    if (_selectedIndex == 0) {
      setState(() {
        deviceList = _fetchDeviceList();
      });
    } else if (_selectedIndex == 1) {
      setState(() {
        routeList = _fetchRouteList();
      });
    } else {
      if (timer) {
        _keyChart.currentState?.updateData();
      } else {
        _keyChart.currentState?.updateBarChart();
      }
    }
  }

  List<Map<String, String>> _fetchDeviceList() {
    var list = widget.vntBox.peerDeviceList();
    return list.map((item) {
      var route = widget.vntBox.route(item.virtualIp);
      var p2pRelay = '';
      var rt = '';
      if (route != null) {
        p2pRelay = route.metric == 1 ? 'P2P' : 'Relay';
        rt = route.rt.toString();
      }
      return {
        'name': item.name,
        'virtualIp': item.virtualIp,
        'status': item.status,
        'p2pRelay': p2pRelay,
        'rt': rt
      };
    }).toList();
  }

  List<Map<String, String>> _fetchRouteList() {
    var list = widget.vntBox.routeList();
    List<Map<String, String>> rs = [];
    for ((String, List<RustRoute>) x in list) {
      for (var route in x.$2) {
        rs.add({
          'destination': x.$1,
          'metric': route.metric.toString(),
          'rt': route.rt.toString(),
          'interface': route.addr
        });
      }
    }
    return rs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('组网', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          if (!Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: IconButton(
                icon: const Text('日志', style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogPage(),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.wysiwyg, color: Colors.white),
              onPressed: _showCurrentDeviceDialog,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.info, color: Colors.white),
              onPressed: _showConfigDialog,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.link_off, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('是否断开连接'),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            Navigator.pop(context, true);
                            await vntManager.remove(widget.config.itemKey);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('断开连接'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                          },
                          child: const Icon(Icons.close),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _buildWidgetOptions(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: '设备',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.router),
            label: '路由',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.signal_cellular_alt),
            label: '统计',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }

  List<Widget> _buildWidgetOptions() {
    // var chartAList = _chartAList();
    return [
      DeviceList(
        deviceList: deviceList,
        vntBox: widget.vntBox,
      ),
      RouteList(routeList: routeList),
      StatisticsChart(
        key: _keyChart,
        vntBox: widget.vntBox,
      )
    ];
  }

  void _showConfigDialog() {
    var conf = json2yaml(widget.vntBox.getNetConfig()!.toJsonSimple());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('网络配置'),
          content: SelectableText(conf),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  void _showCurrentDeviceDialog() {
    Map<String, dynamic> map = widget.vntBox.currentDevice();
    map.addEntries({
      "upStream": widget.vntBox.upStream(),
      "downStream": widget.vntBox.downStream(),
    }.entries);
    var info = json2yaml(map);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('当前设备信息'),
          content: SelectableText(info),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }
}

class DeviceList extends StatelessWidget {
  final VntBox vntBox;
  final List<Map<String, String>> deviceList;

  const DeviceList({super.key, required this.deviceList, required this.vntBox});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: deviceList.length,
            itemBuilder: (context, index) {
              return _buildDeviceRow(deviceList[index], context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(8.0),
      child: const Row(
        children: [
          Expanded(child: Text('Name', textAlign: TextAlign.left)),
          Expanded(child: Text('Virtual Ip', textAlign: TextAlign.left)),
          Expanded(child: Text('Status', textAlign: TextAlign.left)),
          Expanded(child: Text('P2P/Relay', textAlign: TextAlign.left)),
          Expanded(child: Text('Rt', textAlign: TextAlign.left)),
        ],
      ),
    );
  }

  void _showPeerInfoDialog(BuildContext context, String ip, String name) {
    var natInfo = vntBox.peerNatInfo(ip);
    var allRouteList = vntBox.routeList();
    List<RustRoute>? routeList;
    for ((String, List<RustRoute>) routes in allRouteList) {
      if (routes.$1 == ip) {
        routeList = routes.$2;
        break;
      }
    }
    Map<String, dynamic> map;
    if (natInfo != null) {
      map = {
        'name': name,
        'ip': ip,
        'publicIps': natInfo.publicIps,
        'natType': natInfo.natType,
        'localIpv4': natInfo.localIpv4,
        'ipv6': natInfo.ipv6,
      };
    } else {
      map = {
        'name': name,
        'ip': ip,
      };
    }
    if (routeList != null) {
      var route = routeList.map((v) {
        return '$v-${v.metric <= 1 ? "P2P" : "Relay"}-${v.addr} rt=${v.rt}';
      }).toList();
      map.addAll({
        'route': route,
      });
    }

    var info = json2yaml(map);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$ip 设备信息'),
          content: SelectableText(info),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceRow(Map<String, String> device, BuildContext context) {
    return InkWell(
      onTap: () {
        var ip = device['virtualIp'];
        if (ip != null) {
          _showPeerInfoDialog(context, ip, device['name'] ?? '');
        }
      },
      child: Container(
        color: deviceList.indexOf(device) % 2 == 0
            ? Colors.grey[200]
            : Colors.white,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
                child: Text(
              device['name']!,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            )),
            Expanded(
                child: Text(device['virtualIp']!, textAlign: TextAlign.left)),
            Expanded(child: Text(device['status']!, textAlign: TextAlign.left)),
            Expanded(
                child: Text(device['p2pRelay']!, textAlign: TextAlign.left)),
            Expanded(child: Text(device['rt']!, textAlign: TextAlign.left)),
          ],
        ),
      ),
    );
  }
}

class RouteList extends StatelessWidget {
  final List<Map<String, String>> routeList;

  const RouteList({super.key, required this.routeList});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: routeList.length,
            itemBuilder: (context, index) {
              return _buildRouteRow(routeList[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(8.0),
      child: const Row(
        children: [
          Expanded(child: Text('Destination', textAlign: TextAlign.left)),
          Expanded(child: Text('Metric', textAlign: TextAlign.left)),
          Expanded(child: Text('Rt', textAlign: TextAlign.left)),
          Expanded(
              child: Text('Interface',
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1)),
        ],
      ),
    );
  }

  Widget _buildRouteRow(Map<String, String> route) {
    return Container(
      color:
          routeList.indexOf(route) % 2 == 0 ? Colors.grey[200] : Colors.white,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
              child: Text(route['destination']!, textAlign: TextAlign.left)),
          Expanded(child: Text(route['metric']!, textAlign: TextAlign.left)),
          Expanded(child: Text(route['rt']!, textAlign: TextAlign.left)),
          Expanded(child: Text(route['interface']!, textAlign: TextAlign.left)),
        ],
      ),
    );
  }
}
