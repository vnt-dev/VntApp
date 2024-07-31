use std::collections::HashSet;
use std::net::Ipv4Addr;
use std::str::FromStr;
use std::sync::Arc;
use std::thread;

use anyhow::{anyhow, Context};
use flutter_rust_bridge::DartFnFuture;
use tokio::runtime::{Handle, Runtime};
use vnt::channel::punch::{NatInfo, PunchModel};
use vnt::channel::{Route, UseChannelType};
use vnt::cipher::CipherModel;
use vnt::compression::Compressor;
use vnt::core::{Config, Vnt};
use vnt::handle::{CurrentDeviceInfo, PeerDeviceInfo};
#[cfg(target_os = "android")]
use vnt::DeviceConfig;
#[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
use vnt::DeviceInfo;
use vnt::{
    ConnectInfo, ErrorInfo, ErrorType, HandshakeInfo, PeerClientInfo, RegisterInfo, VntCallback,
};

#[flutter_rust_bridge::frb] // Synchronous mode for simplicity of the demo
pub async fn vnt_init(vnt_config: VntConfig, call: VntApiCallback) -> anyhow::Result<VntApi> {
    log::debug!("vnt_init:{:?}", vnt_config);
    match tokio::task::spawn_blocking(|| VntApi::new(vnt_config, call)).await {
        Ok(rs) => match rs {
            Ok(rs) => Ok(rs),
            Err(e) => {
                log::error!("vnt_init {:?}", e);
                Err(anyhow!("vnt_init {:?}", e))
            }
        },
        Err(e) => {
            log::error!("vnt_init spawn_blocking {:?}", e);
            Err(anyhow!("vnt_init spawn_blocking {:?}", e))
        }
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
    init_log();
}
#[cfg(target_os = "android")]
pub fn init_log() {
    use android_logger::Config;
    use log::LevelFilter;
    android_logger::init_once(
        Config::default()
            .with_max_level(LevelFilter::Debug) // limit log level
            .with_tag("vnt_jni"), // logs will show under mytag tag
    );
}
#[cfg(not(target_os = "android"))]
pub fn init_log() {
    let rs = log4rs::init_file("logs/log4rs.yaml", Default::default());
    println!("log  {:?}", rs);
}

#[derive(Clone, Debug)]
pub struct VntConfig {
    pub tap: bool,
    pub token: String,
    pub device_id: String,
    pub name: String,
    pub server_address_str: String,
    pub name_servers: Vec<String>,
    pub stun_server: Vec<String>,
    pub in_ips: Vec<(u32, u32, String)>,
    pub out_ips: Vec<(u32, u32)>,
    pub password: Option<String>,
    pub mtu: Option<u32>,
    pub ip: Option<String>,
    pub no_proxy: bool,
    pub server_encrypt: bool,
    pub cipher_model: String,
    pub finger: bool,
    pub punch_model: String,
    pub ports: Option<Vec<u16>>,
    pub first_latency: bool,
    pub device_name: Option<String>,
    pub use_channel_type: String,
    //控制丢包率
    pub packet_loss_rate: Option<f64>,
    pub packet_delay: u32,
    // 端口映射
    pub port_mapping_list: Vec<String>,
    pub compressor: String,
    pub allow_wire_guard:bool,
    pub local_ipv4:Option<String>,
}

pub struct VntApi {
    vnt: Vnt,
}

impl VntApi {
    pub fn new(vnt_config: VntConfig, call: VntApiCallback) -> anyhow::Result<VntApi> {
        log::debug!("解析参数:{:?}", vnt_config);
        // 转换 in_ips
        let mut in_ips: Vec<(u32, u32, Ipv4Addr)> = Vec::with_capacity(vnt_config.in_ips.len());
        for (a, b, ip_str) in vnt_config.in_ips {
            let ip_addr = Ipv4Addr::from_str(&ip_str)?;
            in_ips.push((a, b, ip_addr))
        }
        let ip = match vnt_config.ip {
            Some(ip_str) => Some(Ipv4Addr::from_str(&ip_str)?),
            None => None,
        };
        let cipher_model = match CipherModel::from_str(&vnt_config.cipher_model) {
            Ok(cipher_model) => cipher_model,
            Err(e) => Err(anyhow!("{:?}", e))?,
        };
        let punch_model = match PunchModel::from_str(&vnt_config.punch_model) {
            Ok(punch_model) => punch_model,
            Err(e) => Err(anyhow!("{:?}", e))?,
        };
        let use_channel_type = match UseChannelType::from_str(&vnt_config.use_channel_type) {
            Ok(use_channel_type) => use_channel_type,
            Err(e) => Err(anyhow!("{:?}", e))?,
        };
        let compressor = match Compressor::from_str(&vnt_config.compressor) {
            Ok(compressor) => compressor,
            Err(e) => Err(anyhow!("{:?}", e))?,
        };
        let local_ipv4:Option<Ipv4Addr> = if let Some(local_ipv4) = vnt_config.local_ipv4{
            Some(local_ipv4.parse().context("localIP")?)
        }else{
            None
        };
        let conf = Config::new(
            #[cfg(target_os = "windows")]
            vnt_config.tap,
            vnt_config.token,
            vnt_config.device_id,
            vnt_config.name,
            vnt_config.server_address_str,
            vnt_config.name_servers,
            vnt_config.stun_server,
            in_ips,
            vnt_config.out_ips,
            vnt_config.password,
            vnt_config.mtu,
            ip,
            vnt_config.no_proxy,
            vnt_config.server_encrypt,
            cipher_model,
            vnt_config.finger,
            punch_model,
            vnt_config.ports,
            vnt_config.first_latency,
            #[cfg(not(target_os = "android"))]
            vnt_config.device_name,
            use_channel_type,
            vnt_config.packet_loss_rate,
            vnt_config.packet_delay,
            vnt_config.port_mapping_list,
            compressor,
            true,
            vnt_config.allow_wire_guard,
            local_ipv4,
        )?;
        Ok(Self {
            vnt: Vnt::new(conf, call)?,
        })
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn stop(&self) {
        self.vnt.stop();
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn is_stopped(&self) -> bool {
        self.vnt.is_stopped()
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn device_list(&self) -> Vec<RustPeerClientInfo> {
        self.vnt
            .device_list()
            .into_iter()
            .map(|v| v.into())
            .collect()
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn route_list(&self) -> Vec<(String, Vec<RustRoute>)> {
        self.vnt
            .route_table()
            .into_iter()
            .map(|(ip, routes)| {
                (
                    ip.to_string(),
                    routes.into_iter().map(|v| v.into()).collect(),
                )
            })
            .collect()
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn nat_info(&self) -> RustNatInfo {
        self.vnt.nat_info().into()
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn current_device(&self) -> RustCurrentDeviceInfo {
        self.vnt.current_device().into()
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn route(&self, ip: &String) -> Option<RustRoute> {
        match Ipv4Addr::from_str(ip) {
            Ok(ip) => self.vnt.route(&ip).map(|v| v.into()),
            Err(_) => None,
        }
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn peer_nat_info(&self, ip: &String) -> Option<RustNatInfo> {
        match Ipv4Addr::from_str(ip) {
            Ok(ip) => self.vnt.peer_nat_info(&ip).map(|v| v.into()),
            Err(_) => None,
        }
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn up_stream(&self) -> String {
        convert(self.vnt.up_stream())
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn down_stream(&self) -> String {
        convert(self.vnt.down_stream())
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn stream_all(&self) -> Vec<(String, u64, u64)> {
        let (_, up_map) = self.vnt.up_stream_all().unwrap_or_default();
        let (_, down_map) = self.vnt.down_stream_all().unwrap_or_default();
        let up_keys: HashSet<Ipv4Addr> = up_map.keys().cloned().collect();
        let down_keys: HashSet<Ipv4Addr> = down_map.keys().cloned().collect();
        let mut keys: Vec<Ipv4Addr> = up_keys.union(&down_keys).cloned().collect();
        keys.sort();
        let mut list = Vec::with_capacity(keys.len());
        for key in keys {
            let up = up_map.get(&key).cloned().unwrap_or_default();
            let down = down_map.get(&key).cloned().unwrap_or_default();
            list.push((key.to_string(), up, down));
        }
        list
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn up_stream_line(&self, ip: String) -> Vec<u64> {
        let ip: Ipv4Addr = if let Ok(ip) = ip.parse() {
            ip
        } else {
            return vec![];
        };
        let (_, mut up_map) = self.vnt.up_stream_history().unwrap_or_default();
        let (_, up_history) = up_map.remove(&ip).unwrap_or_default();

        up_history.into_iter().map(|v| v as u64).collect()
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn down_stream_line(&self, ip: String) -> Vec<u64> {
        let ip: Ipv4Addr = if let Ok(ip) = ip.parse() {
            ip
        } else {
            return vec![];
        };
        let (_, mut down_map) = self.vnt.down_stream_history().unwrap_or_default();
        let (_, down_history) = down_map.remove(&ip).unwrap_or_default();
        down_history.into_iter().map(|v| v as u64).collect()
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn ip_up_stream_total(&self, ip: String) -> String {
        let ip: Ipv4Addr = if let Ok(ip) = ip.parse() {
            ip
        } else {
            return String::new();
        };
        let (_, up_map) = self.vnt.up_stream_all().unwrap_or_default();
        convert(up_map.get(&ip).cloned().unwrap_or_default())
    }
    #[flutter_rust_bridge::frb(sync)]
    pub fn ip_down_stream_total(&self, ip: String) -> String {
        let ip: Ipv4Addr = if let Ok(ip) = ip.parse() {
            ip
        } else {
            return String::new();
        };
        let (_, down_map) = self.vnt.down_stream_all().unwrap_or_default();
        convert(down_map.get(&ip).cloned().unwrap_or_default())
    }
}

fn convert(num: u64) -> String {
    let gigabytes = num / (1024 * 1024 * 1024);
    let remaining_bytes = num % (1024 * 1024 * 1024);
    let megabytes = remaining_bytes / (1024 * 1024);
    let remaining_bytes = remaining_bytes % (1024 * 1024);
    let kilobytes = remaining_bytes / 1024;
    let remaining_bytes = remaining_bytes % 1024;
    let mut s = String::new();
    if gigabytes > 0 {
        s.push_str(&format!("{} GB ", gigabytes));
    }
    if megabytes > 0 {
        s.push_str(&format!("{} MB ", megabytes));
    }
    if kilobytes > 0 {
        s.push_str(&format!("{} KB ", kilobytes));
    }
    if remaining_bytes > 0 {
        s.push_str(&format!("{} bytes", remaining_bytes));
    }
    s
}

#[derive(Clone)]
pub struct VntApiCallback {
    inner: Arc<VntApiCallbackInner>,
}

impl VntApiCallback {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(
        success_fn: impl Fn() -> DartFnFuture<()> + Send + Sync + 'static,
        create_tun_fn: impl Fn(RustDeviceInfo) -> DartFnFuture<()> + Send + Sync + 'static,
        connect_fn: impl Fn(RustConnectInfo) -> DartFnFuture<()> + Send + Sync + 'static,
        handshake_fn: impl Fn(RustHandshakeInfo) -> DartFnFuture<bool> + Send + Sync + 'static,
        register_fn: impl Fn(RustRegisterInfo) -> DartFnFuture<bool> + Send + Sync + 'static,
        // #[cfg(target_os = "android")]
        generate_tun_fn: impl Fn(RustDeviceConfig) -> DartFnFuture<u32> + Send + Sync + 'static,
        peer_client_list_fn: impl Fn(Vec<RustPeerClientInfo>) -> DartFnFuture<()>
            + Send
            + Sync
            + 'static,
        error_fn: impl Fn(RustErrorInfo) -> DartFnFuture<()> + Send + Sync + 'static,
        stop_fn: impl Fn() -> DartFnFuture<()> + Send + Sync + 'static,
    ) -> VntApiCallback {
        Self {
            inner: Arc::new(VntApiCallbackInner {
                success_fn: Box::new(success_fn),
                create_tun_fn: Box::new(create_tun_fn),
                connect_fn: Box::new(connect_fn),
                handshake_fn: Box::new(handshake_fn),
                register_fn: Box::new(register_fn),
                generate_tun_fn: Box::new(generate_tun_fn),
                peer_client_list_fn: Box::new(peer_client_list_fn),
                error_fn: Box::new(error_fn),
                stop_fn: Box::new(stop_fn),
            }),
        }
    }
}

struct VntApiCallbackInner {
    success_fn: Box<dyn Fn() -> DartFnFuture<()> + Send + Sync + 'static>,
    // #[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
    create_tun_fn: Box<dyn Fn(RustDeviceInfo) -> DartFnFuture<()> + Send + Sync + 'static>,
    connect_fn: Box<dyn Fn(RustConnectInfo) -> DartFnFuture<()> + Send + Sync + 'static>,
    handshake_fn: Box<dyn Fn(RustHandshakeInfo) -> DartFnFuture<bool> + Send + Sync + 'static>,
    register_fn: Box<dyn Fn(RustRegisterInfo) -> DartFnFuture<bool> + Send + Sync + 'static>,
    // #[cfg(target_os = "android")]
    generate_tun_fn: Box<dyn Fn(RustDeviceConfig) -> DartFnFuture<u32> + Send + Sync + 'static>,
    peer_client_list_fn:
        Box<dyn Fn(Vec<RustPeerClientInfo>) -> DartFnFuture<()> + Send + Sync + 'static>,
    error_fn: Box<dyn Fn(RustErrorInfo) -> DartFnFuture<()> + Send + Sync + 'static>,
    stop_fn: Box<dyn Fn() -> DartFnFuture<()> + Send + Sync + 'static>,
}

impl VntCallback for VntApiCallback {
    fn success(&self) {
        let inner = self.inner.clone();
        if let Ok(h) = Handle::try_current() {
            h.spawn(async move {
                let f = &inner.success_fn;
                f().await
            });
        } else {
            let f = &inner.success_fn;
            Runtime::new().unwrap().block_on(async { f().await })
        }
    }
    #[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
    fn create_tun(&self, info: DeviceInfo) {
        let inner = self.inner.clone();
        let info = info.into();
        if let Ok(h) = Handle::try_current() {
            h.spawn(async move {
                let f = &inner.create_tun_fn;
                f(info).await
            });
        } else {
            let f = &inner.create_tun_fn;
            Runtime::new().unwrap().block_on(async { f(info).await })
        }
    }

    fn connect(&self, info: ConnectInfo) {
        let inner = self.inner.clone();
        let info = info.into();
        if let Ok(h) = Handle::try_current() {
            h.spawn(async move {
                let f = &inner.connect_fn;
                f(info).await
            });
        } else {
            let f = &inner.connect_fn;
            Runtime::new().unwrap().block_on(async { f(info).await })
        }
    }

    fn handshake(&self, info: HandshakeInfo) -> bool {
        let inner = self.inner.clone();
        let info = info.into();
        if Handle::try_current().is_ok() {
            thread::spawn(move || {
                let f = &inner.handshake_fn;
                Runtime::new().unwrap().block_on(async { f(info).await })
            })
            .join()
            .unwrap()
        } else {
            let f = &inner.handshake_fn;
            Runtime::new().unwrap().block_on(async { f(info).await })
        }
    }

    fn register(&self, info: RegisterInfo) -> bool {
        let inner = self.inner.clone();
        let info = info.into();
        if Handle::try_current().is_ok() {
            thread::spawn(move || {
                let f = &inner.register_fn;
                Runtime::new().unwrap().block_on(async { f(info).await })
            })
            .join()
            .unwrap()
        } else {
            let f = &inner.register_fn;
            Runtime::new().unwrap().block_on(async { f(info).await })
        }
    }
    #[cfg(target_os = "android")]
    fn generate_tun(&self, info: DeviceConfig) -> usize {
        let inner = self.inner.clone();
        let info = info.into();
        if Handle::try_current().is_ok() {
            thread::spawn(move || {
                let f = &inner.generate_tun_fn;
                Runtime::new().unwrap().block_on(async { f(info).await })
            })
            .join()
            .unwrap() as _
        } else {
            let f = &inner.generate_tun_fn;
            Runtime::new().unwrap().block_on(async { f(info).await }) as _
        }
    }
    fn peer_client_list(&self, info: Vec<PeerClientInfo>) {
        let inner = self.inner.clone();
        let info = info.into_iter().map(|v| v.into()).collect();
        if let Ok(h) = Handle::try_current() {
            h.spawn(async move {
                let f = &inner.peer_client_list_fn;
                f(info).await
            });
        } else {
            let f = &inner.peer_client_list_fn;
            Runtime::new().unwrap().block_on(async { f(info).await })
        }
    }

    fn error(&self, info: ErrorInfo) {
        let inner = self.inner.clone();
        let info = info.into();
        if let Ok(h) = Handle::try_current() {
            h.spawn(async move {
                let f = &inner.error_fn;
                f(info).await
            });
        } else {
            let f = &inner.error_fn;
            Runtime::new().unwrap().block_on(async { f(info).await })
        }
    }

    fn stop(&self) {
        let inner = self.inner.clone();
        if let Ok(h) = Handle::try_current() {
            h.spawn(async move {
                let f = &inner.stop_fn;
                f().await
            });
        } else {
            let f = &inner.stop_fn;
            Runtime::new().unwrap().block_on(async { f().await })
        }
    }
}

#[derive(Debug)]
pub struct RustDeviceInfo {
    pub name: String,
    pub version: String,
}

#[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
impl From<DeviceInfo> for RustDeviceInfo {
    fn from(value: DeviceInfo) -> Self {
        RustDeviceInfo {
            name: value.name,
            version: value.version,
        }
    }
}

#[derive(Debug)]
pub struct RustConnectInfo {
    // 第几次连接，从1开始
    pub count: usize,
    // 服务端地址
    pub address: String,
}

impl From<ConnectInfo> for RustConnectInfo {
    fn from(value: ConnectInfo) -> Self {
        Self {
            count: value.count,
            address: value.address.to_string(),
        }
    }
}

#[derive(Debug)]
pub struct RustHandshakeInfo {
    //服务端指纹
    pub finger: Option<String>,
    //服务端版本
    pub version: String,
}

impl From<HandshakeInfo> for RustHandshakeInfo {
    fn from(value: HandshakeInfo) -> Self {
        Self {
            finger: value.finger,
            version: value.version,
        }
    }
}

#[derive(Debug)]
pub struct RustRegisterInfo {
    //本机虚拟IP
    pub virtual_ip: String,
    //子网掩码
    pub virtual_netmask: String,
    //虚拟网关
    pub virtual_gateway: String,
}

impl From<RegisterInfo> for RustRegisterInfo {
    fn from(value: RegisterInfo) -> Self {
        Self {
            virtual_ip: value.virtual_ip.to_string(),
            virtual_netmask: value.virtual_netmask.to_string(),
            virtual_gateway: value.virtual_gateway.to_string(),
        }
    }
}

#[derive(Debug)]
pub struct RustDeviceConfig {
    //本机虚拟IP
    pub virtual_ip: String,
    //子网掩码
    pub virtual_netmask: String,
    //虚拟网关
    pub virtual_gateway: String,
    //虚拟网段
    pub virtual_network: String,
    // 额外的路由
    pub external_route: Vec<(String, String)>,
}

#[cfg(target_os = "android")]
impl From<DeviceConfig> for RustDeviceConfig {
    fn from(value: DeviceConfig) -> Self {
        Self {
            virtual_ip: value.virtual_ip.to_string(),
            virtual_netmask: value.virtual_netmask.to_string(),
            virtual_gateway: value.virtual_gateway.to_string(),
            virtual_network: value.virtual_network.to_string(),
            external_route: value
                .external_route
                .into_iter()
                .map(|(a, b)| (a.to_string(), b.to_string()))
                .collect(),
        }
    }
}

#[derive(Debug)]
pub struct RustPeerClientInfo {
    pub virtual_ip: String,
    pub name: String,
    pub status: String,
    pub client_secret: bool,
}

impl From<PeerClientInfo> for RustPeerClientInfo {
    fn from(value: PeerClientInfo) -> Self {
        Self {
            virtual_ip: value.virtual_ip.to_string(),
            name: value.name,
            status: format!("{:?}", value.status),
            client_secret: value.client_secret,
        }
    }
}

impl From<PeerDeviceInfo> for RustPeerClientInfo {
    fn from(value: PeerDeviceInfo) -> Self {
        Self {
            virtual_ip: value.virtual_ip.to_string(),
            name: value.name,
            status: format!("{:?}", value.status),
            client_secret: value.client_secret,
        }
    }
}

#[derive(Debug)]
pub struct RustErrorInfo {
    pub code: RustErrorType,
    pub msg: Option<String>,
}

impl From<ErrorInfo> for RustErrorInfo {
    fn from(value: ErrorInfo) -> Self {
        Self {
            code: value.code.into(),
            msg: value.msg,
        }
    }
}
#[derive(Debug)]
pub enum RustErrorType {
    TokenError,
    Disconnect,
    AddressExhausted,
    IpAlreadyExists,
    InvalidIp,
    LocalIpExists,
    Unknown,
}
impl From<ErrorType> for RustErrorType {
    fn from(value: ErrorType) -> Self {
        match value {
            ErrorType::TokenError => RustErrorType::TokenError,
            ErrorType::Disconnect => RustErrorType::Disconnect,
            ErrorType::AddressExhausted => RustErrorType::AddressExhausted,
            ErrorType::IpAlreadyExists => RustErrorType::IpAlreadyExists,
            ErrorType::InvalidIp => RustErrorType::InvalidIp,
            ErrorType::LocalIpExists => RustErrorType::LocalIpExists,
            ErrorType::Unknown => RustErrorType::Unknown,
        }
    }
}

#[derive(Debug)]
pub struct RustRoute {
    pub protocol: String,
    pub addr: String,
    pub metric: u8,
    pub rt: i64,
}

impl From<Route> for RustRoute {
    fn from(value: Route) -> Self {
        RustRoute {
            protocol: format!("{:?}", value.protocol),
            addr: value.addr.to_string(),
            metric: value.metric,
            rt: value.rt,
        }
    }
}

#[derive(Debug)]
pub struct RustNatInfo {
    pub public_ips: Vec<String>,
    pub nat_type: String,
    pub local_ipv4: Option<String>,
    pub ipv6: Option<String>,
}

impl From<NatInfo> for RustNatInfo {
    fn from(value: NatInfo) -> Self {
        let local_ipv4 = value.local_ipv4().map(|v| v.to_string());
        let ipv6 = value.ipv6().map(|v| v.to_string());
        Self {
            public_ips: value
                .public_ips
                .into_iter()
                .map(|v| v.to_string())
                .collect(),
            nat_type: format!("{:?}", value.nat_type),
            local_ipv4,
            ipv6,
        }
    }
}

#[derive(Debug)]
pub struct RustCurrentDeviceInfo {
    pub virtual_ip: String,
    //子网掩码
    pub virtual_netmask: String,
    //虚拟网关
    pub virtual_gateway: String,
    //网络地址
    pub virtual_network: String,
    //直接广播地址
    pub broadcast_ip: String,
    //链接的服务器地址
    pub connect_server: String,
    //连接状态
    pub status: String,
}

impl From<CurrentDeviceInfo> for RustCurrentDeviceInfo {
    fn from(value: CurrentDeviceInfo) -> Self {
        Self {
            virtual_ip: value.virtual_ip.to_string(),
            virtual_netmask: value.virtual_netmask.to_string(),
            virtual_gateway: value.virtual_gateway.to_string(),
            virtual_network: value.virtual_network.to_string(),
            broadcast_ip: value.broadcast_ip.to_string(),
            connect_server: value.connect_server.to_string(),
            status: format!("{:?}", value.status),
        }
    }
}
