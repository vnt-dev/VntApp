class Ipv4Addr {
  final String address;

  Ipv4Addr(this.address);

  static Ipv4Addr? tryParse(String input) {
    final regex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    if (regex.hasMatch(input)) {
      return Ipv4Addr(input);
    } else {
      return null;
    }
  }

  List<int> octets() {
    return address.split('.').map((e) => int.parse(e)).toList();
  }

  int toInt() {
    final octets = this.octets();
    return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
  }

  static String fromInt(int ip) {
    final octet1 = (ip >> 24) & 0xFF;
    final octet2 = (ip >> 16) & 0xFF;
    final octet3 = (ip >> 8) & 0xFF;
    final octet4 = ip & 0xFF;
    return '$octet1.$octet2.$octet3.$octet4';
  }

  @override
  String toString() {
    return address;
  }
}

class IpUtils {
  static String toInIpString(int dest, int mask, String ip) {
    return '${Ipv4Addr.fromInt(dest).toString()}/${_countBits(mask)},${ip}';
  }

  static (int, int, String) parseInIpString(String input) {
    final parts = input.split(",");
    if (parts.length != 2) {
      throw Exception("格式错误: $input");
    }

    final netPart = parts[0];
    final ipPart = parts[1];

    final ip = Ipv4Addr.tryParse(ipPart);
    if (ip == null) {
      throw Exception("无效的 IP 地址: $ipPart");
    }

    final netParts = netPart.split("/");
    if (netParts.length != 2) {
      throw Exception("无效的网络格式: $netPart");
    }

    final destPart = netParts[0];
    final maskPart = netParts[1];

    final dest = Ipv4Addr.tryParse(destPart);
    if (dest == null) {
      throw Exception("无效的目的Ipv4: $destPart");
    }

    final mask = toIp(maskPart);

    return (_toU32(dest.octets()), mask, ip.toString());
  }

  static String toOutIpString(int dest, int mask) {
    return '${Ipv4Addr.fromInt(dest).toString()}/${_countBits(mask)}';
  }

  static (int, int) parseOutIpString(String netPart) {
    final netParts = netPart.split("/");
    if (netParts.length != 2) {
      throw Exception("无效的网络格式: $netPart");
    }

    final destPart = netParts[0];
    final maskPart = netParts[1];

    final dest = Ipv4Addr.tryParse(destPart);
    if (dest == null) {
      throw Exception("无效的目的Ipv4: $destPart");
    }

    final mask = toIp(maskPart);

    return (_toU32(dest.octets()), mask);
  }

  static int toIp(String mask) {
    try {
      int maskInt = int.parse(mask);
      return (0xFFFFFFFF << (32 - maskInt)) & 0xFFFFFFFF;
    } catch (e) {
      throw Exception("无效掩码: $mask");
    }
  }

  static int _toU32(List<int> octets) {
    if (octets.length != 4) {
      throw Exception("无效的 IPv4 地址");
    }
    return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
  }

  static int _countBits(int octet) {
    int count = 0;
    while (octet > 0) {
      count += octet & 1;
      octet >>= 1;
    }
    return count;
  }
}
