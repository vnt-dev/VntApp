import 'package:flutter/material.dart';
import 'connect_log.dart';
import 'network_config.dart';
import 'custom_app_bar.dart';
import 'src/rust/api/vnt_api.dart';
import 'vnt/vnt_api.dart';
import 'package:json2yaml/json2yaml.dart';

class ConnectDetailPage extends StatefulWidget {
  final NetworkConfig config;

  const ConnectDetailPage({super.key, required this.config});

  @override
  _ConnectDetailPageState createState() => _ConnectDetailPageState();
}

class _ConnectDetailPageState extends State<ConnectDetailPage> {
  int _selectedIndex = 0;
  List<Map<String, String>> deviceList = [];
  List<Map<String, String>> routeList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_selectedIndex == 0) {
      deviceList = _fetchDeviceList();
      setState(() {
        deviceList = deviceList;
      });
    } else {
      routeList = _fetchRouteList();
      setState(() {
        routeList = routeList;
      });
    }
  }

  List<Map<String, String>> _fetchDeviceList() {
    var list = VntApiUtils.peerDeviceList();
    return list.map((item) {
      var route = VntApiUtils.route(item.virtualIp);
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
    var list = VntApiUtils.routeList();
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Text('日志', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConnectLogPage(),
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
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.pop(context, true);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('断开连接'),
                        ),
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
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }

  List<Widget> _buildWidgetOptions() {
    return [
      DeviceList(deviceList: deviceList),
      RouteList(routeList: routeList),
    ];
  }

  void _showConfigDialog() {
    var conf = json2yaml(VntApiUtils.getNetConfig()!.toJsonSimple());
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
    Map<String, dynamic> map = VntApiUtils.currentDevice();
    map.addEntries({
      "upStream": VntApiUtils.upStream(),
      "downStream": VntApiUtils.downStream(),
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
  final List<Map<String, String>> deviceList;

  const DeviceList({super.key, required this.deviceList});

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
    var natInfo = VntApiUtils.peerNatInfo(ip);
    var allRouteList = VntApiUtils.routeList();
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
        return '${v.isTcp ? "TCP" : "UDP"}-${v.metric <= 1 ? "P2P" : "Relay"}-${v.addr} rt=${v.rt}';
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
