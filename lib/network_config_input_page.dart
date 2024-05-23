import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'data_persistence.dart';
import 'network_config.dart';
import 'dart:io';
import 'widgets/custom_tooltip_text_field.dart';
import 'utils/ip_utils.dart';

class NetworkConfigInputPage extends StatefulWidget {
  final NetworkConfig? config;

  const NetworkConfigInputPage({super.key, this.config});
  @override
  _NetworkConfigInputPageState createState() => _NetworkConfigInputPageState();
}

class _NetworkConfigInputPageState extends State<NetworkConfigInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _groupNumberController = TextEditingController();
  final _deviceNameController = TextEditingController(
      text: Platform.operatingSystemVersion.length > 64
          ? Platform.operatingSystemVersion.substring(0, 64)
          : Platform.operatingSystemVersion);
  final _virtualIPv4Controller = TextEditingController();
  final _serverAddressController = TextEditingController();
  final _stunServers = <TextEditingController>[];
  final _inIps = <TextEditingController>[];
  final _outIps = <TextEditingController>[];
  final _portMappings = <TextEditingController>[];
  final _groupPasswordController = TextEditingController();
  final _dnsControllers = <TextEditingController>[];
  final _deviceIDController = TextEditingController(); // 不可编辑
  final _virtualNetworkCardNameController = TextEditingController();
  final _mtuController = TextEditingController();
  final _portGroupControllers = <TextEditingController>[];
  final _simulatedPacketLossRateController = TextEditingController();
  final _simulatedLatencyController = TextEditingController();

  String _isServerEncrypted = 'OPEN';
  bool _isPasswordVisible = false;
  String _communicationMethod = 'UDP';
  String _dataFingerprintVerification = 'CLOSE';
  String _encryptionAlgorithm = 'aes_gcm';
  String _routingMode = 'P2P';
  String _builtInIpProxy = 'OPEN';
  bool _isMoreParametersVisible = false;
  bool _ipv4Selected = true;
  bool _ipv6Selected = true;
  bool _relaySelected = true;
  bool _p2pSelected = true;

  _NetworkConfigInputPageState() {}

  @override
  void initState() {
    super.initState();
    getDeviceUniqueId();
    if (widget.config != null) {
      _loadConfig(widget.config!);
    } else {
      _loadDefault();
    }
    if (_stunServers.isEmpty) {
      _stunServers.add(TextEditingController());
    }
    if (_inIps.isEmpty) {
      _inIps.add(TextEditingController());
    }
    if (_outIps.isEmpty) {
      _outIps.add(TextEditingController());
    }
    if (_portMappings.isEmpty) {
      _portMappings.add(TextEditingController());
    }
    if (_dnsControllers.isEmpty) {
      _dnsControllers.add(TextEditingController());
    }
    if (_portGroupControllers.isEmpty) {
      _portGroupControllers.add(TextEditingController());
    }
  }

  void _loadDefault() {
    _stunServers.add(TextEditingController(text: "stun1.l.google.com:19302"));
    _stunServers.add(TextEditingController(text: "stun2.l.google.com:19302"));
    _stunServers.add(TextEditingController(text: "stun.miwifi.com:3478"));
    _mtuController.text = "1410";
    _serverAddressController.text = "vnt.wherewego.top:29872";
    _simulatedPacketLossRateController.text = "0";
    _simulatedLatencyController.text = "0";
  }

  void _loadConfig(NetworkConfig config) {
    _nameController.text = config.configName;
    _groupNumberController.text = config.token;
    _deviceNameController.text = config.deviceName;
    _virtualIPv4Controller.text = config.virtualIPv4;
    _serverAddressController.text = config.serverAddress;
    for (String stunServer in config.stunServers) {
      _stunServers.add(TextEditingController(text: stunServer));
    }
    for (String inIp in config.inIps) {
      _inIps.add(TextEditingController(text: inIp));
    }
    for (String outIp in config.outIps) {
      _outIps.add(TextEditingController(text: outIp));
    }
    for (String portMapping in config.portMappings) {
      _portMappings.add(TextEditingController(text: portMapping));
    }
    _groupPasswordController.text = config.groupPassword;
    _isServerEncrypted = config.isServerEncrypted ? 'OPEN' : 'CLOSE';
    _communicationMethod = config.isTcp ? 'TCP' : 'UDP';
    _dataFingerprintVerification =
        config.dataFingerprintVerification ? 'OPEN' : 'CLOSE';
    _encryptionAlgorithm = config.encryptionAlgorithm;
    _deviceIDController.text = config.deviceID;
    _virtualNetworkCardNameController.text = config.virtualNetworkCardName;
    _mtuController.text = config.mtu.toString();
    for (int portGroup in config.ports) {
      _portGroupControllers
          .add(TextEditingController(text: portGroup.toString()));
    }
    for (String dns in config.dns) {
      _dnsControllers.add(TextEditingController(text: dns));
    }
    _simulatedPacketLossRateController.text =
        config.simulatedPacketLossRate.toString();
    _simulatedLatencyController.text = config.simulatedLatency.toString();
    _ipv4Selected = config.punchModel == 'ipv4' || config.punchModel == 'all';
    _ipv6Selected = config.punchModel == 'ipv6' || config.punchModel == 'all';
    _relaySelected =
        config.useChannelType == 'relay' || config.useChannelType == 'all';
    _p2pSelected =
        config.useChannelType == 'p2p' || config.useChannelType == 'all';
    setState(() {
      _routingMode = config.firstLatency ? 'LOW_LATENCY' : 'P2P';
      _builtInIpProxy = config.noInIpProxy ? 'CLOSE' : 'OPEN';
    });
  }

  Future<void> getDeviceUniqueId() async {
    String uniqueId = await DataPersistence().loadUniqueId();
    setState(() {
      _deviceIDController.text = uniqueId;
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      var name = _nameController.text.trim();
      var groupNumber = _groupNumberController.text.trim();
      if (name.isEmpty) {
        if (groupNumber.length > 6) {
          name = groupNumber.substring(0, 6);
        } else {
          name = groupNumber;
        }
      }
      NetworkConfig config = NetworkConfig(
        itemKey: DateTime.now().millisecondsSinceEpoch.toString(),
        configName: name,
        token: _groupNumberController.text,
        deviceName: _deviceNameController.text,
        virtualIPv4: _virtualIPv4Controller.text,
        serverAddress: _serverAddressController.text,
        stunServers: _stunServers
            .map((controller) => controller.text)
            .where((text) => text.isNotEmpty)
            .toList(),
        inIps: _inIps
            .map((controller) => controller.text)
            .where((text) => text.isNotEmpty)
            .toList(),
        outIps: _outIps
            .map((controller) => controller.text)
            .where((text) => text.isNotEmpty)
            .toList(),
        portMappings: _portMappings
            .map((controller) => controller.text)
            .where((text) => text.isNotEmpty)
            .toList(),
        groupPassword: _groupPasswordController.text,
        isServerEncrypted: _isServerEncrypted == 'OPEN',
        isTcp: _communicationMethod == 'TCP',
        dataFingerprintVerification: _dataFingerprintVerification == 'OPEN',
        encryptionAlgorithm: _encryptionAlgorithm,
        deviceID: _deviceIDController.text,
        virtualNetworkCardName: _virtualNetworkCardNameController.text,
        mtu: int.tryParse(_mtuController.text) ?? 1410,
        ports: _portGroupControllers
            .map((controller) => controller.text)
            .where((text) => text.isNotEmpty)
            .map((text) => int.tryParse(text) ?? 0)
            .toList(),
        firstLatency: _routingMode == 'LOW_LATENCY',
        noInIpProxy: _builtInIpProxy == 'CLOSE',
        dns: _dnsControllers
            .map((controller) => controller.text)
            .where((text) => text.isNotEmpty)
            .toList(),
        simulatedPacketLossRate:
            double.tryParse(_simulatedPacketLossRateController.text) ?? 0,
        simulatedLatency: int.tryParse(_simulatedLatencyController.text) ?? 0,
        punchModel: (_ipv4Selected && _ipv6Selected) ||
                (!_ipv4Selected && !_ipv6Selected)
            ? 'all'
            : (_ipv4Selected ? 'ipv4' : 'ipv6'),
        useChannelType: (_p2pSelected && _relaySelected) ||
                (!_p2pSelected && !_relaySelected)
            ? 'all'
            : (_p2pSelected ? 'p2p' : 'relay'),
      );
      Navigator.pop(context, config);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('参数校验失败,请检查标红参数')),
      );
    }
  }

  void _addController(List<TextEditingController> controllers) {
    setState(() {
      controllers.add(TextEditingController());
    });
  }

  void _removeController(int index, List<TextEditingController> controllers) {
    if (controllers.length > 1) {
      setState(() {
        controllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('组网参数配置', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          // if (widget.config == null)
          //   Padding(
          //       padding: const EdgeInsets.symmetric(horizontal: 8.0),
          //       child: Tooltip(
          //           message: '导入',
          //           child: IconButton(
          //             icon:
          //                 const Icon(Icons.call_received, color: Colors.white),
          //             onPressed: _showImportConfigDialog,
          //           ))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                  message: '保存',
                  child: IconButton(
                    icon: const Icon(Icons.save, color: Colors.white),
                    onPressed: _submitForm,
                  ))),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTooltipTextField(
                  controller: _nameController,
                  labelText: '配置名称',
                  tooltipMessage: '(方便区分不同配置项，可填任意字符)',
                  maxLength: 10,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('基本参数'),
                CustomTooltipTextField(
                  controller: _groupNumberController,
                  labelText: '组网编号',
                  tooltipMessage: '(标识同一个虚拟网络)',
                  maxLength: 64,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入组网编号';
                    }
                    return null;
                  },
                ),
                _buildTextFormField(
                  _deviceNameController,
                  '设备名称',
                  64,
                  (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入设备名称';
                    }
                    return null;
                  },
                ),
                CustomTooltipTextField(
                  controller: _virtualIPv4Controller,
                  labelText: '虚拟IPv4',
                  tooltipMessage: '(不输入则由VNTS分配虚拟IPv4)',
                  maxLength: 15,
                  validator: (value) {
                    final regex = RegExp(
                      r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$',
                    );
                    if (value != null &&
                        value.isNotEmpty &&
                        !regex.hasMatch(value)) {
                      return '请输入有效的 IPv4 地址';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomTooltipTextField(
                  controller: _serverAddressController,
                  labelText: '服务器地址',
                  tooltipMessage: '(VNTS地址,可以使用txt:前缀启用TXT记录解析)',
                  maxLength: 64,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '地址不能为空';
                    }
                    final txtRegex = RegExp(r'^txt:');
                    final addressPortRegex = RegExp(r'^(.+):(\d{1,5})$');

                    if (txtRegex.hasMatch(value)) {
                      final txtDomainRegex =
                          RegExp(r'^txt:[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (txtDomainRegex.hasMatch(value)) {
                        return null;
                      }
                      return '域名格式错误';
                    } else {
                      final match = addressPortRegex.firstMatch(value);
                      if (match != null) {
                        final port = int.tryParse(match.group(2)!);
                        if (port != null && port >= 1 && port <= 65535) {
                          return null;
                        } else {
                          return '端口错误';
                        }
                      } else {
                        return '地址格式错误';
                      }
                    }
                  },
                ),
                _buildRadioGroup(
                  '通信方式',
                  [('UDP', 'UDP'), ('TCP', 'TCP')],
                  _communicationMethod,
                  (value) {
                    setState(() {
                      _communicationMethod = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('子网代理&端口映射'),
                _buildDynamicTooltipFields(
                  'in-ip',
                  _inIps,
                  '示例：192.168.0.1/24,10.26.0.10',
                  34,
                  IpUtils.parseInIpString,
                ),
                _buildDynamicTooltipFields(
                  'out-ip',
                  _outIps,
                  '示例：0.0.0.0/0',
                  18,
                  IpUtils.parseOutIpString,
                ),
                _buildDynamicTooltipFields(
                  '端口映射',
                  _portMappings,
                  '示例：tcp:0.0.0.0:80->10.26.0.10:80',
                  48,
                  (value) {
                    final regex =
                        RegExp(r'^(tcp|udp):[^:]+:(\d{1,5})->[^:]+:(\d{1,5})$');
                    final match = regex.firstMatch(value);

                    if (match != null) {
                      final int port1 = int.parse(match.group(2)!);
                      final int port2 = int.parse(match.group(3)!);

                      if ((port1 >= 1 && port1 <= 65535) &&
                          (port2 >= 1 && port2 <= 65535)) {
                        return null;
                      } else {
                        throw const FormatException("端口取值1~65535");
                      }
                    }
                    throw const FormatException("格式错误");
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('传输安全'),
                _buildTextFormField(
                  _groupPasswordController,
                  '组网密码',
                  256,
                  null,
                  null,
                  true,
                  !_isPasswordVisible,
                  IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                _buildDropdownField(
                  '加密算法',
                  ['aes_gcm', 'aes_cbc', 'aes_ecb', 'sm4_cbc'],
                  _encryptionAlgorithm,
                  (value) {
                    setState(() {
                      _encryptionAlgorithm = value.toString();
                    });
                  },
                ),
                _buildRadioGroup(
                  '服务端加密',
                  [('开启', 'OPEN'), ('关闭', 'CLOSE')],
                  _isServerEncrypted,
                  (value) {
                    setState(() {
                      _isServerEncrypted = value!;
                    });
                  },
                ),
                _buildRadioGroup(
                  '数据指纹校验',
                  [('开启', 'OPEN'), ('关闭', 'CLOSE')],
                  _dataFingerprintVerification,
                  (value) {
                    setState(() {
                      _dataFingerprintVerification = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('更多参数'),
                Visibility(
                  visible: _isMoreParametersVisible,
                  child: Column(
                    children: [
                      _buildTextFormField(
                        _deviceIDController,
                        '设备编号',
                        null,
                        null,
                        null,
                        false,
                      ),
                      _buildTextFormField(
                        _virtualNetworkCardNameController,
                        '虚拟网卡名称',
                        10,
                      ),
                      _buildTextFormField(
                        _mtuController,
                        '虚拟网卡mtu',
                        null,
                        (value) {
                          if (value == null || value.isEmpty) {
                            return null;
                          }
                          final n = num.tryParse(value);
                          if (n == null || n <= 0) {
                            return '请输入有效的正整数';
                          }
                          return null;
                        },
                        TextInputType.number,
                      ),
                      _buildFormFieldWithValidation(
                        '打洞模式',
                        _ipv4Selected,
                        _ipv6Selected,
                        (value) {
                          setState(() {
                            _ipv4Selected = value!;
                          });
                        },
                        (value) {
                          setState(() {
                            _ipv6Selected = value!;
                          });
                        },
                      ),
                      _buildFormFieldWithValidation(
                        '传输模式',
                        _relaySelected,
                        _p2pSelected,
                        (value) {
                          setState(() {
                            _relaySelected = value!;
                          });
                        },
                        (value) {
                          setState(() {
                            _p2pSelected = value!;
                          });
                        },
                      ),
                      _buildDynamicFields(
                        '端口',
                        _portGroupControllers,
                        _addController,
                        _removeController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null;
                          }
                          final n = int.tryParse(value);
                          if (n == null || n < 0 || n > 65535) {
                            return '请输入0到65535之间的数字';
                          }
                          return null;
                        },
                      ),
                      _buildRadioGroup(
                        '路径模式',
                        [('P2P优先', 'P2P'), ('低延迟优先', 'LOW_LATENCY')],
                        _routingMode,
                        (value) {
                          setState(() {
                            _routingMode = value!;
                          });
                        },
                      ),
                      _buildRadioGroup(
                        '内置IP代理',
                        [('开启', 'OPEN'), ('关闭', 'CLOSE')],
                        _builtInIpProxy,
                        (value) {
                          setState(() {
                            _builtInIpProxy = value!;
                          });
                        },
                      ),
                      _buildDynamicFields(
                        'dns',
                        _dnsControllers,
                        _addController,
                        _removeController,
                      ),
                      _buildTextFormField(
                        _simulatedPacketLossRateController,
                        '模拟丢包率',
                        null,
                        (value) {
                          final n = num.tryParse(value ?? '');
                          if (n != null && (n < 0 || n > 1)) {
                            return '请输入0到1之间的小数';
                          }
                          return null;
                        },
                        TextInputType.numberWithOptions(decimal: true),
                      ),
                      _buildTextFormField(
                        _simulatedLatencyController,
                        '模拟延迟',
                        null,
                        (value) {
                          final n = num.tryParse(value ?? '');
                          if (n != null && n < 0) {
                            return '请输入有效的整数';
                          }
                          return null;
                        },
                        TextInputType.number,
                      ),
                      _buildDynamicFields(
                        'stun服务器',
                        _stunServers,
                        _addController,
                        _removeController,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isMoreParametersVisible = !_isMoreParametersVisible;
                    });
                  },
                  child: Text(_isMoreParametersVisible ? '隐藏更多参数' : '显示更多参数'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String labelText,
    int? maxLength, [
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool enabled = true,
    bool obscureText = false,
    Widget? suffixIcon,
  ]) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        suffixIcon: suffixIcon,
      ),
      maxLength: maxLength,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: obscureText,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRadioGroup(
    String title,
    List<(String, String)> list,
    String groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(title),
        ),
        Expanded(
          child: Row(
            children: list.map(((String, String) x) {
              return Row(
                children: [
                  Radio<String>(
                    value: x.$2,
                    groupValue: groupValue,
                    onChanged: onChanged,
                  ),
                  Text(x.$1),
                  const SizedBox(width: 20),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicFields(
    String label,
    List<TextEditingController> controllers,
    Function(List<TextEditingController>) addController,
    Function(int, List<TextEditingController>) removeController, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      children: [
        ...controllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                      labelText: '$label${index == 0 ? '' : ' ---$index'}'),
                  maxLength: 32,
                  keyboardType: keyboardType,
                  validator: validator,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle),
                onPressed: () => removeController(index, controllers),
              ),
            ],
          );
        }).toList(),
        Row(
          children: [
            Expanded(child: Container()),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () => addController(controllers),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDynamicTooltipFields(
    String label,
    List<TextEditingController> controllers,
    String tooltipMessage,
    int maxLength,
    Function(String) parser,
  ) {
    return Column(
      children: [
        ...controllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Row(
            children: [
              Expanded(
                child: CustomTooltipTextField(
                  controller: controller,
                  labelText: '$label${index == 0 ? '' : ' ---$index'}',
                  tooltipMessage: tooltipMessage,
                  maxLength: maxLength,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null;
                    }
                    try {
                      parser(value);
                    } catch (e) {
                      return e.toString();
                    }
                    return null;
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle),
                onPressed: () => _removeController(index, controllers),
              ),
            ],
          );
        }).toList(),
        Row(
          children: [
            Expanded(child: Container()),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () => _addController(controllers),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String labelText,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField(
      value: value,
      decoration: InputDecoration(labelText: labelText),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildFormFieldWithValidation(
    String title,
    bool selectedValue1,
    bool selectedValue2,
    ValueChanged<bool?> onChanged1,
    ValueChanged<bool?> onChanged2,
  ) {
    return FormField<bool>(
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedValue1,
                        onChanged: onChanged1,
                      ),
                      Text('IPv4'),
                      const SizedBox(width: 20),
                      Checkbox(
                        value: selectedValue2,
                        onChanged: onChanged2,
                      ),
                      Text('IPv6'),
                    ],
                  ),
                ),
              ],
            ),
            if (!selectedValue1 && !selectedValue2)
              const Padding(
                padding: EdgeInsets.only(top: 5.0),
                child: Text(
                  '至少勾选一个选项',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
      validator: (value) {
        if (!selectedValue1 && !selectedValue2) {
          return '至少勾选一个选项';
        }
        return null;
      },
    );
  }
}
