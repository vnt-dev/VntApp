package top.wherewego.vnt_app;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.File;
import java.io.FileInputStream;
import java.io.OutputStream;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import top.wherewego.vnt_app.vpn.DeviceConfig;
import top.wherewego.vnt_app.vpn.MyVpnService;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private static final int VPN_REQUEST_CODE = 1;
    private static final int CREATE_FILE_REQUEST_CODE = 2;
    private static final int NOTIFICATION_PERMISSION_REQUEST_CODE = 3;

    private static final String FILE_CHANNEL = "top.wherewego.vnt/file";
    private MethodChannel fileChannel;
    private String pendingFilePath;
    private MethodChannel.Result pendingFileResult;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // 设置应用上下文，用于更新磁贴和小组件
        FlutterMethodChannel.setAppContext(this);

        // Android 13+ 需要先请求通知权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestNotificationPermission();
        } else {
            // Android 13 以下直接启动通知服务
            startNotificationService();
        }
    }

    /**
     * 请求通知权限（Android 13+）
     */
    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                // 请求通知权限
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.POST_NOTIFICATIONS},
                        NOTIFICATION_PERMISSION_REQUEST_CODE);
            } else {
                // 已有权限，启动通知服务
                startNotificationService();
            }
        }
    }

    /**
     * 处理权限请求结果
     */
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "通知权限已授予，启动通知服务");
                startNotificationService();
            } else {
                Log.w(TAG, "通知权限被拒绝，跳过通知服务启动");
                // 即使没有通知权限，应用也应该能正常运行
            }
        }
    }

    /**
     * 启动常驻通知服务
     */
    private void startNotificationService() {
        try {
            Intent serviceIntent = new Intent(this, VntNotificationService.class);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Android 8.0+ 使用 startForegroundService
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            Log.d(TAG, "常驻通知服务已启动");
        } catch (Exception e) {
            Log.e(TAG, "启动通知服务失败: " + e.getMessage(), e);
            // 不要让通知服务启动失败阻止应用运行
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        MyVpnService.stopVpn();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // VPN Channel
        FlutterMethodChannel.init(flutterEngine, new FlutterMethodChannel.Callback() {
            @Override
            public int startVpn(DeviceConfig config) {
                startVpnService(config);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    MyTileService.setState(true);
                }
                return 0;
            }

            @Override
            public void stopVpn() {
                MyVpnService.stopVpn();
            }

            @Override
            public void moveToBack() {
                moveTaskToBack(true);
            }
        });

        // Flutter 初始化完成后，立即更新通知服务状态
        VntNotificationService.updateNotification(this);

        // File Channel - 用于文件保存
        fileChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), FILE_CHANNEL);
        fileChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("saveFile")) {
                String filePath = call.argument("filePath");
                String fileName = call.argument("fileName");
                String mimeType = call.argument("mimeType");

                if (filePath == null || fileName == null) {
                    result.error("INVALID_ARGUMENT", "filePath and fileName are required", null);
                    return;
                }

                pendingFilePath = filePath;
                pendingFileResult = result;

                // 使用 SAF 创建文件
                createFile(fileName, mimeType != null ? mimeType : "*/*");
            } else {
                result.notImplemented();
            }
        });
    }

    private void createFile(String fileName, String mimeType) {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType(mimeType);
        intent.putExtra(Intent.EXTRA_TITLE, fileName);

        startActivityForResult(intent, CREATE_FILE_REQUEST_CODE);
    }

    private void startVpnService(DeviceConfig config) {
        MyVpnService.pendingConfig = config;
        // 每次启动都重新检查权限，这样如果有其他 VPN 运行，系统会弹窗让用户选择
        Intent intent = VpnService.prepare(this);
        if (intent != null) {
            // 需要用户授权，系统会提示断开其他 VPN
            startActivityForResult(intent, VPN_REQUEST_CODE);
        } else {
            // 已有权限，直接启动
            Intent serviceIntent = new Intent(this, MyVpnService.class);
            startService(serviceIntent);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                Intent serviceIntent = new Intent(this, MyVpnService.class);
                startService(serviceIntent);
            } else {
                FlutterMethodChannel.callError("User denied VPN authorization", null);
            }
        } else if (requestCode == CREATE_FILE_REQUEST_CODE) {
            if (resultCode == RESULT_OK && data != null) {
                Uri uri = data.getData();
                if (uri != null && pendingFilePath != null) {
                    // 复制文件到用户选择的位置
                    copyFileToUri(pendingFilePath, uri);
                } else {
                    if (pendingFileResult != null) {
                        pendingFileResult.error("SAVE_FAILED", "Failed to get URI", null);
                        pendingFileResult = null;
                    }
                }
            } else {
                // 用户取消
                if (pendingFileResult != null) {
                    pendingFileResult.success(null);
                    pendingFileResult = null;
                }
            }
            pendingFilePath = null;
        }
        super.onActivityResult(requestCode, resultCode, data);
    }

    private void copyFileToUri(String sourcePath, Uri destUri) {
        try {
            File sourceFile = new File(sourcePath);
            FileInputStream inputStream = new FileInputStream(sourceFile);
            OutputStream outputStream = getContentResolver().openOutputStream(destUri);

            if (outputStream == null) {
                throw new Exception("Cannot open output stream");
            }

            byte[] buffer = new byte[4096];
            int length;
            while ((length = inputStream.read(buffer)) > 0) {
                outputStream.write(buffer, 0, length);
            }

            outputStream.flush();
            outputStream.close();
            inputStream.close();

            if (pendingFileResult != null) {
                pendingFileResult.success(destUri.toString());
                pendingFileResult = null;
            }

            Log.d(TAG, "File saved successfully to: " + destUri.toString());
        } catch (Exception e) {
            Log.e(TAG, "Error saving file", e);
            if (pendingFileResult != null) {
                pendingFileResult.error("SAVE_FAILED", e.getMessage(), null);
                pendingFileResult = null;
            }
        }
    }
}
