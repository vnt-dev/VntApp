package top.wherewego.vnt_app;

import android.content.Context;
import android.os.Build;
import android.service.quicksettings.Tile;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import top.wherewego.vnt_app.vpn.DeviceConfig;
import top.wherewego.vnt_app.vpn.IpUtils;

public class FlutterMethodChannel {
    private static final String CHANNEL = "top.wherewego.vnt/vpn";

    private volatile static MethodChannel channel;
    private volatile static MethodChannel.Result pendingResult;
    private volatile static boolean tileStart = false;
    private volatile static String tileConfigKey = null; // 从磁贴选择的配置key
    private volatile static Context appContext; // 保存应用上下文

    public static void setTileStart(boolean tileStart) {
        FlutterMethodChannel.tileStart = tileStart;
    }

    public static void setTileConfigKey(String configKey) {
        FlutterMethodChannel.tileConfigKey = configKey;
    }

    public static String getTileConfigKey() {
        String key = tileConfigKey;
        tileConfigKey = null; // 读取后清空
        return key;
    }

    public static boolean initialized() {
        return channel != null;
    }

    public static void init(FlutterEngine flutterEngine, Callback callback) {
        channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "startVpn":
                            DeviceConfig config;
                            try {
                                Map<String, Object> arguments = call.arguments();
                                config = parseDeviceConfig(arguments);
                            } catch (Exception e) {
                                result.error("VPN_ERROR", "Invalid DeviceConfig", e);
                                return;
                            }
                            try {
                                pendingResult = result;
                                callback.startVpn(config);
                            } catch (Exception e) {
                                result.error("VPN_ERROR", e.getMessage(), e);
                            }

                            break;
                        case "stopVpn":
                            callback.stopVpn();
                            result.success(null);
                            break;
                        case "moveTaskToBack":
                            callback.moveToBack();
                            result.success(null);
                            break;
                        case "isTileStart":
                            result.success(tileStart);
                            break;
                        case "getTileConfigKey":
                            result.success(getTileConfigKey());
                            break;
                        case "updateWidgetAndTile":
                            // 更新磁贴和小组件状态
                            Boolean isConnected = call.argument("isConnected");
                            if (isConnected != null && appContext != null) {
                                updateWidgetAndTileState(appContext, isConnected);
                            }
                            result.success(null);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                }
        );
    }

    public static void callSuccess(int fd) {
        if (pendingResult != null) {
            pendingResult.success(fd);
        }
        pendingResult = null;
    }

    public static void callError(String msg, Exception e) {
        if (pendingResult != null) {
            pendingResult.error("VPN_ERROR", msg, e);
        }
        pendingResult = null;
    }

    public static void startVnt(String configKey, Function<Boolean, Void> function) {
        if (channel == null) {
            return;
        }
        channel.invokeMethod("startVnt", configKey, new MethodChannel.Result() {
            @Override
            public void success(@Nullable Object result) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    function.apply(Boolean.TRUE.equals(result));
                }
            }

            @Override
            public void error(@NonNull String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                Log.e("FlutterChannel", errorMessage);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    function.apply(false);
                }
            }

            @Override
            public void notImplemented() {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    function.apply(false);
                }
            }
        });
    }

    public static void stopVnt() {
        if (channel == null) {
            return;
        }
        channel.invokeMethod("stopVnt", null);
    }

    public static void isRunning(Function<Boolean, Void> function) {
        if (channel == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                function.apply(false);
            }
            return;
        }
        channel.invokeMethod("isRunning", null, new MethodChannel.Result() {
            @Override
            public void success(@Nullable Object result) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    function.apply(Boolean.TRUE.equals(result));
                }
            }

            @Override
            public void error(@NonNull String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                Log.e("FlutterChannel", errorMessage);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    function.apply(false);
                }
            }

            @Override
            public void notImplemented() {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    function.apply(false);
                }
            }
        });
    }

    public static void getDeviceInfo(Function<Map<String, Object>, Void> function) {
        if (channel == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                Map<String, Object> emptyInfo = new HashMap<>();
                emptyInfo.put("isConnected", false);
                emptyInfo.put("configName", "");
                emptyInfo.put("onlineCount", 0);
                emptyInfo.put("offlineCount", 0);
                function.apply(emptyInfo);
            }
            return;
        }
        channel.invokeMethod("getDeviceInfo", null, new MethodChannel.Result() {
            @Override
            public void success(@Nullable Object result) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    if (result instanceof Map) {
                        function.apply((Map<String, Object>) result);
                    } else {
                        Map<String, Object> emptyInfo = new HashMap<>();
                        emptyInfo.put("isConnected", false);
                        emptyInfo.put("configName", "");
                        emptyInfo.put("onlineCount", 0);
                        emptyInfo.put("offlineCount", 0);
                        function.apply(emptyInfo);
                    }
                }
            }

            @Override
            public void error(@NonNull String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {
                Log.e("FlutterChannel", "getDeviceInfo error: " + errorMessage);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    Map<String, Object> emptyInfo = new HashMap<>();
                    emptyInfo.put("isConnected", false);
                    emptyInfo.put("configName", "");
                    emptyInfo.put("onlineCount", 0);
                    emptyInfo.put("offlineCount", 0);
                    function.apply(emptyInfo);
                }
            }

            @Override
            public void notImplemented() {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    Map<String, Object> emptyInfo = new HashMap<>();
                    emptyInfo.put("isConnected", false);
                    emptyInfo.put("configName", "");
                    emptyInfo.put("onlineCount", 0);
                    emptyInfo.put("offlineCount", 0);
                    function.apply(emptyInfo);
                }
            }
        });
    }

    private static DeviceConfig parseDeviceConfig(Map<String, Object> arguments) {
        String virtualIp = (String) arguments.get("virtualIp");
        String virtualNetmask = (String) arguments.get("virtualNetmask");
        String virtualGateway = (String) arguments.get("virtualGateway");
        Integer mtu = (Integer) arguments.get("mtu");

        List<Map<String, String>> externalRouteList = (List<Map<String, String>>) arguments.get("externalRoute");
        List<DeviceConfig.Route> externalRoute = new ArrayList<>();
        if (externalRouteList != null) {
            for (Map<String, String> route : externalRouteList) {
                String destination = route.get("destination");
                String netmask = route.get("netmask");
                externalRoute.add(new DeviceConfig.Route(IpUtils.ipToInt(destination), IpUtils.ipToInt(netmask)));
            }
        }
        return new DeviceConfig(IpUtils.ipToInt(virtualIp), IpUtils.ipToInt(virtualNetmask), IpUtils.ipToInt(virtualGateway), mtu, externalRoute);
    }

    /**
     * 设置应用上下文（在 MainActivity 中调用）
     */
    public static void setAppContext(Context context) {
        appContext = context.getApplicationContext();
    }

    /**
     * 更新磁贴和小组件状态
     * @param context 上下文
     * @param isConnected 是否已连接
     */
    public static void updateWidgetAndTileState(Context context, boolean isConnected) {
        Log.i("FlutterChannel", "更新磁贴和小组件状态: isConnected=" + isConnected);

        // 更新磁贴状态
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            MyTileService.setState(isConnected);
        }

        // 更新小组件状态
        VntWidget.updateAllWidgets(context);

        // 更新常驻通知
        VntNotificationService.updateNotification(context);
    }

    public interface Callback {
        int startVpn(DeviceConfig config);

        void stopVpn();

        void moveToBack();
    }
}
