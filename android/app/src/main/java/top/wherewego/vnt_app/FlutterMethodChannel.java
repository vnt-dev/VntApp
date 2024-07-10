package top.wherewego.vnt_app;

import android.os.Build;
import android.service.quicksettings.Tile;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
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

    public static void setTileStart(boolean tileStart) {
        FlutterMethodChannel.tileStart = tileStart;
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

    public static void startVnt(Function<Boolean, Void> function) {
        if (channel == null) {
            return;
        }
        channel.invokeMethod("startVnt", null, new MethodChannel.Result() {
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

    public interface Callback {
        int startVpn(DeviceConfig config);

        void stopVpn();

        void moveToBack();
    }
}
