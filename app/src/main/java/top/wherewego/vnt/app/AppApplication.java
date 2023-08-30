package top.wherewego.vnt.app;

import android.app.Application;
import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.core.content.ContextCompat;

import com.google.gson.Gson;
import com.scwang.smart.refresh.header.MaterialHeader;
import com.scwang.smart.refresh.layout.SmartRefreshLayout;

import java.util.ArrayList;

import top.wherewego.vnt.R;
import top.wherewego.vnt.util.SPUtils;
import top.wherewego.vnt.jni.ConfigurationInfoBean;

/**
 * author : Android 轮子哥
 * github : https://github.com/getActivity/AndroidProject
 * time   : 2018/10/18
 * desc   : 应用入口
 */
public final class AppApplication extends Application {
    public static ArrayList<ConfigurationInfoBean> configList = new ArrayList<>();

    @Override
    public void onCreate() {
        super.onCreate();
        initSdk(this);
    }

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);

        String keyset = SPUtils.getString(this, "keyset", "0");
        if (!keyset.equals("0")) {
            String[] strArray = null;
            strArray = keyset.split(","); //拆分字符为"," ,然后把结果交给数组strArray
            Log.d("swichapp", "attachBaseContext: keyset : " + keyset);
            for (String s : strArray) {
                Log.d("swichapp", "attachBaseContext: s : " + s);
                String json = SPUtils.getString(this, s, "0");
                if (json.equals("0")) {
                    continue;
                }
                ConfigurationInfoBean configurationInfoBean = new Gson().fromJson(json, ConfigurationInfoBean.class);
                configList.add(configurationInfoBean);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    configList.sort((v1, v2) -> v2.getKey().compareTo(v1.getKey()));
                }
            }
        }
        Log.d("swichapp", "configList: size : " + configList.size());
    }

    @Override
    public void onLowMemory() {
        super.onLowMemory();
        // 清理所有图片内存缓存
        //GlideApp.get(this).onLowMemory();
    }

    @Override
    public void onTrimMemory(int level) {
        super.onTrimMemory(level);
        // 根据手机内存剩余情况清理图片内存缓存
        //GlideApp.get(this).onTrimMemory(level);
    }

    /**
     * 初始化一些第三方框架
     */
    public static void initSdk(Application application) {
        // 设置标题栏初始化器
        //TitleBar.setDefaultStyle(new TitleBarStyle());

        // 设置全局的 Header 构建器
        SmartRefreshLayout.setDefaultRefreshHeaderCreator((cx, layout) ->
                new MaterialHeader(application).setColorSchemeColors(ContextCompat.getColor(application, R.color.common_accent_color)));
        // 设置全局的 Footer 构建器
        // SmartRefreshLayout.setDefaultRefreshFooterCreator((cx, layout) -> new SmartBallPulseFooter(application));
        // 设置全局初始化器
        SmartRefreshLayout.setDefaultRefreshInitializer((cx, layout) -> {
            // 刷新头部是否跟随内容偏移
            layout.setEnableHeaderTranslationContent(true)
                    // 刷新尾部是否跟随内容偏移
                    .setEnableFooterTranslationContent(true)
                    // 加载更多是否跟随内容偏移
                    .setEnableFooterFollowWhenNoMoreData(true)
                    // 内容不满一页时是否可以上拉加载更多
                    .setEnableLoadMoreWhenContentNotFull(false)
                    // 仿苹果越界效果开关
                    .setEnableOverScrollDrag(false);
        });

        // 初始化吐司
//        ToastUtils.init(application, new ToastStyle());
//        // 设置调试模式
//        ToastUtils.setDebugMode(AppConfig.isDebug());
//        // 设置 Toast 拦截器
//        ToastUtils.setInterceptor(new ToastLogInterceptor());
//
//        // 本地异常捕捉
//        CrashHandler.register(application);
//
//        // 友盟统计、登录、分享 SDK
//        UmengClient.init(application, AppConfig.isLogEnable());
//
//        // Bugly 异常捕捉
//        CrashReport.initCrashReport(application, AppConfig.getBuglyId(), AppConfig.isDebug());
//
//        // Activity 栈管理初始化
//        ActivityManager.getInstance().init(application);
//
//        // MMKV 初始化
//        MMKV.initialize(application);
//
//        // 网络请求框架初始化
//        OkHttpClient okHttpClient = new OkHttpClient.Builder()
//                .build();
//
//        EasyConfig.with(okHttpClient)
//                // 是否打印日志
//                .setLogEnabled(AppConfig.isLogEnable())
//                // 设置服务器配置
//                .setServer(new RequestServer())
//                // 设置请求处理策略
//                .setHandler(new RequestHandler(application))
//                // 设置请求重试次数
//                .setRetryCount(1)
//                .setInterceptor((api, params, headers) -> {
//                    // 添加全局请求头
//                    headers.put("token", "66666666666");
//                    headers.put("deviceOaid", UmengClient.getDeviceOaid());
//                    headers.put("versionName", AppConfig.getVersionName());
//                    headers.put("versionCode", String.valueOf(AppConfig.getVersionCode()));
//                    // 添加全局请求参数
//                    // params.put("6666666", "6666666");
//                })
//                .into();
//
//        // 设置 Json 解析容错监听
//        GsonFactory.setJsonCallback((typeToken, fieldName, jsonToken) -> {
//            // 上报到 Bugly 错误列表
//            CrashReport.postCatchedException(new IllegalArgumentException(
//                    "类型解析异常：" + typeToken + "#" + fieldName + "，后台返回的类型为：" + jsonToken));
//        });
//
//        // 初始化日志打印
//        if (AppConfig.isLogEnable()) {
//            Timber.plant(new DebugLoggerTree());
//        }
//
//        // 注册网络状态变化监听
//        ConnectivityManager connectivityManager = ContextCompat.getSystemService(application, ConnectivityManager.class);
//        if (connectivityManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
//            connectivityManager.registerDefaultNetworkCallback(new ConnectivityManager.NetworkCallback() {
//                @Override
//                public void onLost(@NonNull Network network) {
//                    Activity topActivity = ActivityManager.getInstance().getTopActivity();
//                    if (!(topActivity instanceof LifecycleOwner)) {
//                        return;
//                    }
//
//                    LifecycleOwner lifecycleOwner = ((LifecycleOwner) topActivity);
//                    if (lifecycleOwner.getLifecycle().getCurrentState() != Lifecycle.State.RESUMED) {
//                        return;
//                    }
//
//                    ToastUtils.show(R.string.common_network_error);
//                }
//            });
//        }
    }
}