//
//  VNT-Bridging-Header.h
//  VNT iOS/tvOS Bridging Header
//
//  定义Rust FFI函数的C接口
//

#ifndef VNT_Bridging_Header_h
#define VNT_Bridging_Header_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 初始化iOS日志系统
/// @param log_dir 日志目录路径（C字符串）
/// @return 0=成功, 负数=错误码
int32_t vnt_ios_init_log(const char* log_dir);

/// 从文件描述符启动VNT隧道（iOS/tvOS）
/// @param fd 从NEPacketTunnelProvider获取的文件描述符
/// @param server_addr VNT服务器地址（C字符串）
/// @param token 认证令牌（C字符串）
/// @param device_name 设备名称（C字符串）
/// @param mtu MTU值
/// @return 0表示成功，负数表示错误码
int32_t vnt_ios_start_tunnel(int32_t fd, const char* server_addr, const char* token, const char* device_name, int32_t mtu);

/// 停止VNT隧道
void vnt_ios_stop_tunnel(void);

/// 获取VNT连接状态
/// @return 0=离线, 1=在线, -1=无实例
int32_t vnt_ios_get_status(void);

/// 设置日志级别
/// @param level 日志级别 (0=Error, 1=Warn, 2=Info, 3=Debug, 4=Trace)
void vnt_ios_set_log_level(int32_t level);

#ifdef __cplusplus
}
#endif

#endif /* VNT_Bridging_Header_h */
