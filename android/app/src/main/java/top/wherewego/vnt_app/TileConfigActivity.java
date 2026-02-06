package top.wherewego.vnt_app;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * 磁贴配置选择 Activity
 * 长按磁贴时显示配置选择对话框
 */
public class TileConfigActivity extends Activity {
    private static final String TAG = "TileConfigActivity";
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    private static final String DATA_KEY_NATIVE = "flutter.data-key-native"; // 供原生代码读取的 JSON 格式
    private static final String DEFAULT_KEY = "flutter.default-key";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // 读取配置列表
        List<ConfigItem> configs = loadConfigs();

        if (configs.isEmpty()) {
            // 如果没有配置，提示用户
            new AlertDialog.Builder(this)
                .setTitle("提示")
                .setMessage("暂无配置，请先在应用中创建配置")
                .setPositiveButton("确定", (dialog, which) -> finish())
                .setOnCancelListener(dialog -> finish())
                .show();
            return;
        }

        // 读取当前默认配置
        String currentDefaultKey = loadDefaultKey();

        // 构建配置名称列表
        String[] configNames = new String[configs.size()];
        int selectedIndex = -1;
        for (int i = 0; i < configs.size(); i++) {
            ConfigItem config = configs.get(i);
            configNames[i] = config.name;
            if (config.key.equals(currentDefaultKey)) {
                selectedIndex = i;
            }
        }

        // 显示配置选择对话框
        new AlertDialog.Builder(this)
            .setTitle("连接到选中配置？")
            .setSingleChoiceItems(configNames, selectedIndex, (dialog, which) -> {
                // 获取选择的配置
                ConfigItem selectedConfig = configs.get(which);
                Log.i(TAG, "用户选择配置: " + selectedConfig.name + " (key: " + selectedConfig.key + ")");

                // 立即连接该配置（不保存为默认配置）
                if (!FlutterMethodChannel.initialized()) {
                    Log.i(TAG, "Flutter 未初始化，启动应用并传递配置key");
                    // 通过Intent传递配置key，应用启动后会连接该配置
                    FlutterMethodChannel.setTileStart(true);
                    FlutterMethodChannel.setTileConfigKey(selectedConfig.key);
                    Intent intent = new Intent(TileConfigActivity.this, MainActivity.class);
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(intent);
                } else {
                    Log.i(TAG, "Flutter 已初始化，调用 startVnt 连接配置: " + selectedConfig.key);
                    // Flutter已初始化，直接调用连接，传递配置key
                    // Flutter端会自动处理断开当前连接并连接新配置的逻辑
                    FlutterMethodChannel.startVnt(selectedConfig.key, isRunning -> {
                        Log.i(TAG, "连接配置 [" + selectedConfig.name + "] - isRunning: " + isRunning);
                        // 更新磁贴和小组件状态                
                        FlutterMethodChannel.updateWidgetAndTileState(TileConfigActivity.this, isRunning);
                        return null;
                    });
                }

                dialog.dismiss();
                finish();
            })
            .setNegativeButton("取消", (dialog, which) -> finish())
            .setOnCancelListener(dialog -> finish())
            .show();
    }

    /**
     * 从 SharedPreferences 读取配置列表
     */
    private List<ConfigItem> loadConfigs() {
        List<ConfigItem> configs = new ArrayList<>();
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);

            // 调试：打印所有键
            Log.d(TAG, "所有 SharedPreferences 键: " + prefs.getAll().keySet());

            // 读取供原生代码使用的 JSON 格式配置列表
            String jsonArrayStr = prefs.getString(DATA_KEY_NATIVE, null);
            Log.d(TAG, "读取到的配置数据 (DATA_KEY_NATIVE=" + DATA_KEY_NATIVE + "): " + jsonArrayStr);

            if (jsonArrayStr != null && !jsonArrayStr.isEmpty()) {
                // 这是一个 JSON 数组字符串，包含多个配置的 JSON 字符串
                JSONArray jsonArray = new JSONArray(jsonArrayStr);
                Log.d(TAG, "解析后的 JSON 数组长度: " + jsonArray.length());

                for (int i = 0; i < jsonArray.length(); i++) {
                    String configJsonStr = jsonArray.getString(i);
                    Log.d(TAG, "配置 " + i + ": " + configJsonStr);
                    JSONObject configJson = new JSONObject(configJsonStr);

                    String key = configJson.optString("itemKey", "");
                    String name = configJson.optString("config_name", "未命名配置");

                    if (!key.isEmpty()) {
                        configs.add(new ConfigItem(key, name));
                        Log.d(TAG, "添加配置: key=" + key + ", name=" + name);
                    }
                }
            } else {
                Log.w(TAG, "未找到配置数据 (键名: " + DATA_KEY_NATIVE + ")");
            }
        } catch (Exception e) {
            Log.e(TAG, "读取配置列表失败", e);
        }
        Log.d(TAG, "最终读取到 " + configs.size() + " 个配置");
        return configs;
    }

    /**
     * 读取默认配置 key
     */
    private String loadDefaultKey() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String defaultKey = prefs.getString(DEFAULT_KEY, "");
        Log.d(TAG, "读取默认配置 key (DEFAULT_KEY=" + DEFAULT_KEY + "): " + defaultKey);

        // 如果没有读��到，尝试不带前缀的键名
        if (defaultKey.isEmpty()) {
            defaultKey = prefs.getString("default-key", "");
            Log.d(TAG, "尝试读取 default-key: " + defaultKey);
        }

        return defaultKey;
    }

    /**
     * 保存默认配置 key
     */
    private void saveDefaultKey(String key) {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        // 使用 commit() 而不是 apply()，确保立即同步保存
        // 这样用户长按磁贴修改默认配置后立即点击连接时，能读取到最新的配置
        prefs.edit().putString(DEFAULT_KEY, key).commit();
        Log.i(TAG, "已设置默认配置: " + key);
    }

    /**
     * 配置项
     */
    private static class ConfigItem {
        String key;
        String name;

        ConfigItem(String key, String name) {
            this.key = key;
            this.name = name;
        }
    }
}
