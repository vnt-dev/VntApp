import 'package:flutter/material.dart';

import 'vnt/vnt_api.dart';

class ConnectLogPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('连接日志'),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '更多日志到程序logs目录下查看',
                style: TextStyle(fontSize: 15),
              ),
            ),
            Expanded(
              child: ListView(
                children: VntApiUtils.logQueue.map((log) {
                  return ListTile(
                    title: Text(log.message),
                    subtitle: Text(log.date.toString()),
                  );
                }).toList(),
              ),
            )
          ],
        ));
  }
}
