package com.rustvnt.vntapp;

import android.Manifest;
import android.app.AlertDialog;
import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Space;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.core.content.ContextCompat;
import androidx.core.view.GravityCompat;
import androidx.drawerlayout.widget.DrawerLayout;
import com.vnt.VntApi;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends AppCompatActivity {
    private static final int INDIGO = Color.rgb(79, 70, 229);
    private static final int GREEN = Color.rgb(22, 163, 74);
    private static final int RED = Color.rgb(220, 38, 38);
    private static final int AMBER = Color.rgb(217, 119, 6);
    private static final String LATEST_RELEASE_API =
            "https://api.github.com/repos/vnt-dev/VntApp/releases/latest";

    private DrawerLayout drawer;
    private LinearLayout pageHost;
    private TextView title;
    private TextView status;
    private View sidebarDot;
    private TextView sidebarStatus;
    private final List<TextView> navViews = new ArrayList<>();
    private final List<Page> navPages = new ArrayList<>();
    private VntConfigStore store;
    private VntConfigStore.Profile pendingProfile;
    private Page page = Page.DASHBOARD;
    private boolean dark;
    private boolean stateReceiverRegistered;
    private final ExecutorService updateExecutor = Executors.newSingleThreadExecutor();

    private final ActivityResultLauncher<Intent> vpnPermission = registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(), result -> {
                if (result.getResultCode() == RESULT_OK && pendingProfile != null) {
                    VntVpnService.start(this, pendingProfile);
                    pendingProfile = null;
                } else {
                    pendingProfile = null;
                    toast("需要 VPN 权限才能创建 VNT 虚拟网卡");
                }
            });

    private final ActivityResultLauncher<String> notificationPermission = registerForActivityResult(
            new ActivityResultContracts.RequestPermission(), granted -> { });

    private final BroadcastReceiver stateReceiver = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            render(page != Page.ABOUT);
        }
    };

    @Override protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new VntConfigStore(this);
        dark = getPreferences(MODE_PRIVATE).getBoolean("dark", false);
        AppCompatDelegate.setDefaultNightMode(dark ? AppCompatDelegate.MODE_NIGHT_YES : AppCompatDelegate.MODE_NIGHT_NO);
        buildShell();
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS);
        }
    }

    @Override protected void onStart() {
        super.onStart();
        if (!stateReceiverRegistered) {
            ContextCompat.registerReceiver(this, stateReceiver, new IntentFilter(VntVpnService.ACTION_STATE),
                    ContextCompat.RECEIVER_NOT_EXPORTED);
            stateReceiverRegistered = true;
        }
        VntVpnService.setUiVisible(true);
        render();
    }

    @Override protected void onStop() {
        VntVpnService.setUiVisible(false);
        if (stateReceiverRegistered) {
            unregisterReceiver(stateReceiver);
            stateReceiverRegistered = false;
        }
        super.onStop();
    }

    @Override protected void onDestroy() {
        updateExecutor.shutdownNow();
        super.onDestroy();
    }

    private void buildShell() {
        drawer = new DrawerLayout(this);
        drawer.setStatusBarBackgroundColor(bgHeader());

        LinearLayout main = column();
        main.setBackgroundColor(bgPage());
        drawer.addView(main, new DrawerLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        LinearLayout header = row();
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(10), 0, dp(12), 0);
        header.setBackgroundColor(bgHeader());
        main.addView(header, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(64)));

        Button menu = iconButton("☰");
        menu.setContentDescription("打开导航");
        menu.setOnClickListener(v -> drawer.openDrawer(GravityCompat.START));
        header.addView(menu, size(44, 44));

        LinearLayout heading = column();
        heading.setPadding(dp(5), 0, 0, 0);
        title = text("网络总览", 18, true, textStrong());
        heading.addView(title);
        heading.addView(text("VNT 虚拟局域网管理", 11, false, textMuted()));
        header.addView(heading, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        status = chip("未运行", textMuted(), bgChip());
        header.addView(status);
        Button theme = iconButton(dark ? "☀" : "☾");
        theme.setOnClickListener(v -> {
            dark = !dark;
            getPreferences(MODE_PRIVATE).edit().putBoolean("dark", dark).apply();
            AppCompatDelegate.setDefaultNightMode(dark ? AppCompatDelegate.MODE_NIGHT_YES : AppCompatDelegate.MODE_NIGHT_NO);
            recreate();
        });
        header.addView(theme, size(40, 40));

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        pageHost = column();
        pageHost.setPadding(dp(16), dp(18), dp(16), dp(28));
        scroll.addView(pageHost);
        main.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        LinearLayout navigation = column();
        navigation.setBackgroundColor(bgHeader());
        DrawerLayout.LayoutParams navParams = new DrawerLayout.LayoutParams(dp(288), ViewGroup.LayoutParams.MATCH_PARENT);
        navParams.gravity = GravityCompat.START;
        drawer.addView(navigation, navParams);
        buildNavigation(navigation);

        setContentView(drawer);
    }

    private void buildNavigation(LinearLayout navigation) {
        LinearLayout brand = row();
        brand.setGravity(Gravity.CENTER_VERTICAL);
        brand.setPadding(dp(20), 0, dp(20), 0);
        ImageView logo = new ImageView(this);
        logo.setImageResource(com.rustvnt.vntapp.R.drawable.vnt_icon);
        logo.setContentDescription("VNT");
        brand.addView(logo, size(32, 32));
        LinearLayout brandText = column();
        brandText.setPadding(dp(12), 0, 0, 0);
        brandText.addView(text("VNT", 15, true, textStrong()));
        TextView brandSub = text("CONTROL CENTER", 9, true, textMuted());
        brandSub.setLetterSpacing(0.18f);
        brandText.addView(brandSub);
        navigation.addView(brand, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(64)));
        View brandDivider = new View(this);
        brandDivider.setBackgroundColor(border());
        navigation.addView(brandDivider, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)));

        LinearLayout statusCard = row();
        statusCard.setGravity(Gravity.CENTER_VERTICAL);
        statusCard.setPadding(dp(12), 0, dp(12), 0);
        statusCard.setBackground(round(bgChip(), 12, border(), 1));
        sidebarDot = new View(this);
        LinearLayout.LayoutParams dotParams = size(10, 10);
        dotParams.rightMargin = dp(10);
        statusCard.addView(sidebarDot, dotParams);
        LinearLayout statusTexts = column();
        TextView statusLabel = text("虚拟网络", 9, true, textMuted());
        statusLabel.setLetterSpacing(0.1f);
        statusTexts.addView(statusLabel);
        sidebarStatus = text("未运行", 12, false, textBody());
        statusTexts.addView(sidebarStatus, top(3));
        statusCard.addView(statusTexts);
        LinearLayout.LayoutParams statusParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56));
        statusParams.leftMargin = dp(12);
        statusParams.rightMargin = dp(12);
        statusParams.topMargin = dp(16);
        navigation.addView(statusCard, statusParams);

        navigation.addView(nav("▦", "网络总览", Page.DASHBOARD), navItemParams(dp(16)));
        navigation.addView(nav("♙", "在线设备", Page.PEERS), navItemParams(dp(4)));
        navigation.addView(nav("⇄", "路由表", Page.ROUTES), navItemParams(dp(4)));
        navigation.addView(nav("⚙", "组网配置", Page.CONFIG), navItemParams(dp(4)));
        navigation.addView(nav("ⓘ", "关于", Page.ABOUT), navItemParams(dp(4)));

        Space space = new Space(this);
        navigation.addView(space, new LinearLayout.LayoutParams(1, 0, 1));
        View footerDivider = new View(this);
        footerDivider.setBackgroundColor(border());
        LinearLayout.LayoutParams dividerParams = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1));
        dividerParams.leftMargin = dp(12);
        dividerParams.rightMargin = dp(12);
        navigation.addView(footerDivider, dividerParams);
        LinearLayout footer = row();
        footer.setGravity(Gravity.CENTER_VERTICAL);
        footer.setPadding(dp(18), dp(14), dp(18), dp(14));
        View coreDot = new View(this);
        coreDot.setBackground(round(GREEN, 3, 0, 0));
        LinearLayout.LayoutParams coreDotParams = size(6, 6);
        coreDotParams.rightMargin = dp(8);
        footer.addView(coreDot, coreDotParams);
        footer.addView(text("Rust 核心已就绪", 11, false, textMuted()), weighted());
        footer.addView(text(coreVersion(), 10, false, textMuted()));
        navigation.addView(footer);
    }

    private LinearLayout.LayoutParams navItemParams(int topMargin) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44));
        params.leftMargin = dp(12);
        params.rightMargin = dp(12);
        params.topMargin = topMargin;
        return params;
    }

    private View nav(String icon, String label, Page target) {
        TextView item = text(icon + "    " + label, 14, false, textBody());
        item.setGravity(Gravity.CENTER_VERTICAL);
        item.setPadding(dp(12), 0, dp(8), 0);
        item.setOnClickListener(v -> {
            page = target;
            drawer.closeDrawer(GravityCompat.START);
            render();
        });
        navViews.add(item);
        navPages.add(target);
        return item;
    }

    private void updateSidebar(VntState current) {
        if (sidebarStatus != null) {
            sidebarStatus.setText(switch (current.status) {
                case RUNNING -> "运行中";
                case STARTING -> "正在启动";
                case STOPPING -> "正在停止";
                case ERROR -> "连接失败";
                default -> "未运行";
            });
        }
        if (sidebarDot != null) {
            int color = current.status == VntState.Status.RUNNING ? GREEN :
                    current.status == VntState.Status.STARTING || current.status == VntState.Status.STOPPING ? AMBER :
                            dark ? Color.rgb(71, 85, 105) : Color.rgb(203, 213, 225);
            sidebarDot.setBackground(round(color, 5, 0, 0));
        }
        for (int i = 0; i < navViews.size(); i++) {
            boolean active = navPages.get(i) == page;
            TextView item = navViews.get(i);
            item.setTextColor(active ? INDIGO : textBody());
            item.setTypeface(Typeface.create("sans", active ? Typeface.BOLD : Typeface.NORMAL));
            item.setBackground(round(active ? colorWithAlpha(INDIGO, 25) : Color.TRANSPARENT, 10, 0, 0));
        }
    }

    private void render() { render(true); }

    private void render(boolean rebuildPage) {
        VntState current = VntVpnService.state();
        title.setText(page.title);
        String statusText = switch (current.status) {
            case RUNNING -> "● " + (current.ip == null || current.ip.isEmpty() ? "获取中" : current.ip);
            case STARTING -> "● 正在启动";
            case STOPPING -> "● 正在停止";
            case ERROR -> "● 连接失败";
            default -> "● 未运行";
        };
        status.setText(statusText);
        status.setTextColor(current.status == VntState.Status.RUNNING ? GREEN :
                current.status == VntState.Status.ERROR ? RED :
                        current.status == VntState.Status.STARTING || current.status == VntState.Status.STOPPING ? AMBER : textMuted());
        updateSidebar(current);
        if (!rebuildPage) return;
        pageHost.removeAllViews();
        switch (page) {
            case DASHBOARD -> dashboard(current);
            case PEERS -> peers(current);
            case ROUTES -> routes(current);
            case CONFIG -> configs(current);
            case ABOUT -> about();
        }
    }

    private void dashboard(VntState current) {
        List<VntConfigStore.Profile> profiles = store.all();
        int online = 0;
        for (VntApi.ClientInfo client : current.clients) if (client.online()) online++;
        LinearLayout stats = row();
        stats.addView(statCard("在线设备", String.valueOf(online)), weighted());
        int connected = 0;
        for (VntApi.ServerInfo server : current.servers) if (server.connected()) connected++;
        String serverText = current.status == VntState.Status.RUNNING ? connected + " / " + current.servers.size() : "-";
        stats.addView(statCard("服务器连接", serverText), weightedWithStart());
        pageHost.addView(stats);

        LinearLayout startCard = card();
        startCard.addView(text("启动组网", 16, true, textStrong()));
        if (profiles.isEmpty()) {
            startCard.addView(text("还没有任何配置，先创建一个组网配置吧。", 13, false, textMuted()), top(10));
            Button create = primary("去新建配置");
            create.setOnClickListener(v -> { page = Page.CONFIG; render(); });
            startCard.addView(create, top(14));
        } else if (current.status == VntState.Status.STOPPED || current.status == VntState.Status.ERROR) {
            startCard.addView(text("选择一个配置并建立虚拟网络。", 13, false, textMuted()), top(10));
            startCard.addView(text("选择配置", 12, true, textBody()), top(14));
            LinearLayout startRow = row();
            startRow.setGravity(Gravity.CENTER_VERTICAL);
            Spinner profileSelect = new Spinner(this);
            String[] names = new String[profiles.size()];
            for (int i = 0; i < profiles.size(); i++) names[i] = profiles.get(i).name;
            profileSelect.setAdapter(spinnerAdapter(names));
            startRow.addView(spinnerBox(profileSelect), weighted());
            Button start = primary("启动");
            start.setOnClickListener(v -> {
                int index = profileSelect.getSelectedItemPosition();
                if (index < 0 || index >= profiles.size()) { toast("请先选择一个配置"); return; }
                requestVpn(profiles.get(index));
            });
            LinearLayout.LayoutParams startParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            startParams.leftMargin = dp(12);
            startRow.addView(start, startParams);
            startCard.addView(startRow, top(6));
        } else if (current.status == VntState.Status.RUNNING || current.status == VntState.Status.STARTING) {
            startCard.addView(text(current.message, 13, false, textMuted()), top(10));
            Button stop = danger(current.status == VntState.Status.STARTING ? "取消连接" : "停止组网");
            stop.setOnClickListener(v -> confirmStop());
            startCard.addView(stop, top(14));
        }
        pageHost.addView(startCard, top(16));

        sectionTitle("实例概览");
        if (current.status == VntState.Status.STOPPED) empty("暂无运行中的组网，请在上方选择配置启动");
        else instanceCard(current);
        if (current.status == VntState.Status.RUNNING) {
            networkDetail(current);
            serverList(current);
        }
    }

    private void networkDetail(VntState current) {
        VntConfigStore.Profile profile = current.profileId == null ? null : store.find(current.profileId);
        JSONObject config = profile == null ? new JSONObject() : profile.config();
        LinearLayout card = card();
        card.addView(text("网络详情", 16, true, textStrong()));
        VntApi.NetworkInfo network = current.network;
        detailRow(card, "虚拟 IP / 掩码", network == null ? current.ip == null ? "-" : current.ip
                : network.ip() + " / " + network.prefixLen());
        detailRow(card, "网关", network == null ? "-" : network.gateway());
        detailRow(card, "网络编号", config.optString("network_code", "-"));
        detailRow(card, "MTU", String.valueOf(config.optInt("mtu", 1380)));
        detailRow(card, "NAT 类型", current.nat == null ? "-" : current.nat.type());
        detailRow(card, "Public IPv6", current.nat == null || current.nat.ipv6() == null ? "-" : current.nat.ipv6());
        detailRow(card, "设备名称", config.optString("device_name", "-"));
        detailRow(card, "设备 ID", config.optString("device_id", "-"));
        LinearLayout features1 = row();
        features1.addView(featureChip("加密", !config.optString("password").isEmpty()), weighted());
        features1.addView(featureChip("压缩", config.optBoolean("compress")), weightedWithStart());
        card.addView(features1, top(12));
        LinearLayout features2 = row();
        features2.addView(featureChip("FEC 纠错", config.optBoolean("fec")), weighted());
        features2.addView(featureChip("QUIC 传输", config.optBoolean("rtx")), weightedWithStart());
        card.addView(features2, top(8));
        card.addView(text("Public IPv4s", 12, false, textMuted()), top(14));
        LinearLayout ips = row();
        List<String> publicIps = current.nat == null ? Collections.emptyList() : current.nat.publicIps();
        if (publicIps.isEmpty()) {
            ips.addView(text("无", 12, false, textMuted()));
        } else {
            for (String publicIp : publicIps) {
                TextView ipChip = text(publicIp, 11, false, GREEN);
                ipChip.setTypeface(Typeface.MONOSPACE);
                ipChip.setTextIsSelectable(true);
                ipChip.setPadding(dp(8), dp(4), dp(8), dp(4));
                ipChip.setBackground(round(colorWithAlpha(GREEN, 22), 6, border(), 1));
                ips.addView(ipChip, end(6));
            }
        }
        card.addView(ips, top(8));
        pageHost.addView(card, top(16));
    }

    private void detailRow(LinearLayout card, String label, String value) {
        TextView labelView = text(label, 13, false, textMuted());
        labelView.setTextIsSelectable(true);
        TextView valueView = text(value, 13, false, textStrong());
        valueView.setTypeface(Typeface.MONOSPACE);
        valueView.setTextIsSelectable(true);
        // 标签固定占 1/3，值在右侧 2/3 区域内右对齐、过长自动换行
        LinearLayout row = row();
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(0, dp(9), 0, dp(9));
        row.addView(labelView, weighted());
        valueView.setGravity(Gravity.END);
        LinearLayout.LayoutParams valueParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 2);
        row.addView(valueView, valueParams);
        card.addView(row, top(4));
        View divider = new View(this);
        divider.setBackgroundColor(border());
        card.addView(divider, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)));
    }

    private View featureChip(String label, boolean enabled) {
        LinearLayout item = row();
        item.setGravity(Gravity.CENTER_VERTICAL);
        item.setPadding(dp(10), dp(8), dp(10), dp(8));
        item.setBackground(round(bgChip(), 8, 0, 0));
        View dot = new View(this);
        dot.setBackground(round(enabled ? GREEN : dark ? Color.rgb(71, 85, 105) : Color.rgb(203, 213, 225), 4, 0, 0));
        LinearLayout.LayoutParams dotParams = size(8, 8);
        dotParams.rightMargin = dp(8);
        item.addView(dot, dotParams);
        item.addView(text(label, 12, false, textBody()));
        return item;
    }

    private void serverList(VntState current) {
        LinearLayout card = card();
        card.addView(text("服务器连接列表", 16, true, textStrong()));
        if (current.servers.isEmpty()) card.addView(text("暂无数据", 12, false, textMuted()), top(12));
        for (VntApi.ServerInfo server : current.servers) {
            LinearLayout rowLayout = row();
            rowLayout.setGravity(Gravity.CENTER_VERTICAL);
            LinearLayout info = column();
            TextView address = text(server.address(), 13, true, textStrong());
            address.setTypeface(Typeface.MONOSPACE);
            address.setTextIsSelectable(true);
            info.addView(address);
            String sub = "延迟 " + (server.rtt() == null ? "-" : server.rtt() + " ms")
                    + "    版本 " + (server.version() == null ? "-" : server.version());
            info.addView(text(sub, 11, false, textMuted()), top(4));
            rowLayout.addView(info, weighted());
            rowLayout.addView(chip(server.connected() ? "已连接" : "未连接",
                    server.connected() ? GREEN : RED,
                    colorWithAlpha(server.connected() ? GREEN : RED, 25)));
            card.addView(rowLayout, top(12));
        }
        pageHost.addView(card, top(16));
    }

    private void instanceCard(VntState current) {
        LinearLayout card = card();
        LinearLayout head = row();
        head.setGravity(Gravity.CENTER_VERTICAL);
        head.addView(text(current.profileName == null ? "VNT" : current.profileName, 16, true, textStrong()), weighted());
        int color = current.status == VntState.Status.RUNNING ? GREEN : current.status == VntState.Status.ERROR ? RED : AMBER;
        head.addView(chip(statusLabel(current.status), color, colorWithAlpha(color, 28)));
        card.addView(head);
        card.addView(labelValue("虚拟 IP", current.ip == null ? "-" : current.ip, INDIGO), top(12));
        int online = 0, direct = 0;
        for (VntApi.ClientInfo client : current.clients) {
            if (client.online()) online++;
            if (client.online() && client.direct()) direct++;
        }
        card.addView(text("在线  " + online + "       直连  " + direct + "       离线  " + (current.clients.size() - online), 12, false, textMuted()), top(12));
        card.addView(text(current.message, 12, false, textMuted()), top(10));
        pageHost.addView(card);
    }

    private void peers(VntState current) {
        if (current.status != VntState.Status.RUNNING) { empty("请先启动一个组网实例"); return; }
        int online = 0;
        for (VntApi.ClientInfo client : current.clients) if (client.online()) online++;
        pageHost.addView(text("在线 " + online + "    总计 " + current.clients.size(), 12, false, textMuted()));
        if (current.clients.isEmpty()) { empty("当前网络中暂无其他设备"); return; }
        for (VntApi.ClientInfo client : current.clients) {
            LinearLayout card = card();
            LinearLayout head = row();
            head.setGravity(Gravity.CENTER_VERTICAL);
            head.addView(text(client.ip(), 15, true, INDIGO), weighted());
            head.addView(chip(client.online() ? "在线" : "离线", client.online() ? GREEN : textMuted(),
                    client.online() ? colorWithAlpha(GREEN, 25) : bgChip()));
            card.addView(head);
            String mode = client.online() ? (client.direct() ? "P2P 直连" : "服务器中继") : "-";
            card.addView(labelValue("连接模式", mode, client.direct() ? GREEN : AMBER), top(10));
            if (client.loss() != null) card.addView(labelValue("丢包率", String.format(Locale.US, "%.1f%%", client.loss().rate()), textBody()), top(8));
            if (client.traffic() != null) card.addView(labelValue("流量", "↑ " + bytes(client.traffic().txBytes()) + "   ↓ " + bytes(client.traffic().rxBytes()), textBody()), top(8));
            pageHost.addView(card, top(12));
        }
    }

    private void routes(VntState current) {
        if (current.status != VntState.Status.RUNNING) { empty("暂无运行中的组网实例"); return; }
        sectionTitle("路由表");
        if (current.routes.isEmpty()) { empty("暂未发现可用路由"); return; }
        for (VntApi.RouteInfo group : current.routes) {
            LinearLayout card = card();
            card.addView(text(group.ip(), 15, true, INDIGO));
            if (group.routes().isEmpty()) card.addView(text("暂无路由", 12, false, textMuted()), top(8));
            for (VntApi.RouteDetail route : group.routes()) {
                card.addView(text(route.protocol() + "  " + route.key(), 12, true, textBody()), top(10));
                card.addView(text("Metric " + route.metric() + "    " + route.rtt() + " ms", 11, false, textMuted()), top(3));
            }
            pageHost.addView(card, top(12));
        }
    }

    private void configs(VntState current) {
        LinearLayout action = row();
        action.setGravity(Gravity.CENTER_VERTICAL);
        action.addView(text("配置文件", 16, true, textStrong()), weighted());
        Button add = primary("＋ 新建配置");
        add.setOnClickListener(v -> editProfile(null));
        action.addView(add);
        pageHost.addView(action);
        List<VntConfigStore.Profile> profiles = store.all();
        if (profiles.isEmpty()) { empty("暂无配置，请新建一个组网配置"); return; }
        boolean sessionActive = isSessionActive(current.status);
        for (VntConfigStore.Profile profile : profiles) {
            JSONObject config = profile.config();
            LinearLayout card = card();
            LinearLayout head = row();
            head.setGravity(Gravity.CENTER_VERTICAL);
            head.addView(text(profile.name, 16, true, textStrong()), weighted());
            boolean activeProfile = sessionActive && profile.id.equals(current.profileId);
            if (activeProfile) {
                int stateColor = current.status == VntState.Status.RUNNING ? GREEN : AMBER;
                head.addView(chip(statusLabel(current.status), stateColor,
                        colorWithAlpha(stateColor, 25)));
            }
            card.addView(head);
            card.addView(labelValue("网络编号", config.optString("network_code", "-"), INDIGO), top(10));
            JSONArray servers = config.optJSONArray("server");
            card.addView(labelValue("服务器", servers == null ? "-" : servers.optString(0), textBody()), top(7));
            LinearLayout buttons = row();
            Button connection;
            if (activeProfile) {
                connection = current.status == VntState.Status.STOPPING
                        ? ghost("停止中")
                        : danger(current.status == VntState.Status.STARTING ? "取消启动" : "停止");
                connection.setEnabled(current.status != VntState.Status.STOPPING);
                if (connection.isEnabled()) connection.setOnClickListener(v -> confirmStop());
            } else {
                connection = primary("启动");
                connection.setEnabled(!sessionActive);
                if (sessionActive) {
                    connection.setTextColor(textMuted());
                    connection.setBackground(round(bgInput(), 9, border(), 1));
                } else {
                    connection.setOnClickListener(v -> requestVpn(profile));
                }
            }
            buttons.addView(connection, end(8));
            Button edit = ghost("编辑");
            edit.setOnClickListener(v -> editProfile(profile));
            buttons.addView(edit, end(8));
            Button delete = ghost("删除");
            delete.setEnabled(!activeProfile);
            delete.setTextColor(activeProfile ? textMuted() : RED);
            delete.setOnClickListener(v -> new AlertDialog.Builder(this).setTitle("删除配置")
                    .setMessage("确定要删除 “" + profile.name + "” 吗？")
                    .setNegativeButton("取消", null).setPositiveButton("删除", (d, w) -> { store.delete(profile.id); render(); }).show());
            buttons.addView(delete);
            card.addView(buttons, top(14));
            pageHost.addView(card, top(12));
        }
    }

    private void about() {
        String currentVersion = currentVersion();
        LinearLayout hero = card();
        ImageView logo = new ImageView(this);
        logo.setImageResource(com.rustvnt.vntapp.R.drawable.vnt_icon);
        logo.setContentDescription("VNT");
        hero.addView(logo, size(64, 64));
        hero.addView(text("VNT", 20, true, textStrong()), top(12));
        hero.addView(text("简单、高效的异地组网与内网穿透工具", 13, false, textMuted()), top(5));
        hero.addView(text("Android 客户端 v" + currentVersion + " · Rust 核心 " + coreVersion(),
                11, false, textMuted()), top(10));
        pageHost.addView(hero);

        LinearLayout update = card();
        update.addView(text("版本更新", 15, true, textStrong()));
        update.addView(text("当前版本 v" + currentVersion, 13, false, textMuted()), top(9));
        Button checkUpdate = primary("检查更新");
        checkUpdate.setOnClickListener(v -> checkForUpdates(checkUpdate, currentVersion));
        update.addView(checkUpdate, top(12));
        pageHost.addView(update, top(14));

        LinearLayout source = card();
        source.addView(text("开源项目", 15, true, textStrong()));
        source.addView(text("项目代码、使用说明和问题反馈均托管在 GitHub", 13, false, textMuted()), top(9));
        TextView repositoryUrl = text("github.com/vnt-dev/vnt", 13, true, INDIGO);
        repositoryUrl.setTextIsSelectable(true);
        repositoryUrl.setOnClickListener(v -> copyToClipboard(
                "VNT GitHub 地址", "https://github.com/vnt-dev/vnt"));
        source.addView(repositoryUrl, top(12));
        pageHost.addView(source, top(14));
    }

    private void copyToClipboard(String label, String value) {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        clipboard.setPrimaryClip(ClipData.newPlainText(label, value));
        toast("GitHub 地址已复制");
    }

    private void checkForUpdates(Button button, String currentVersion) {
        button.setEnabled(false);
        button.setText("检查中…");
        updateExecutor.execute(() -> {
            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) new URL(LATEST_RELEASE_API).openConnection();
                connection.setConnectTimeout(10_000);
                connection.setReadTimeout(10_000);
                connection.setRequestProperty("Accept", "application/vnd.github+json");
                connection.setRequestProperty("User-Agent", "VNT-Android");
                int statusCode = connection.getResponseCode();
                if (statusCode != HttpURLConnection.HTTP_OK) {
                    throw new IllegalStateException("GitHub 返回 HTTP " + statusCode);
                }

                StringBuilder response = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                        connection.getInputStream(), StandardCharsets.UTF_8))) {
                    char[] buffer = new char[4096];
                    int count;
                    while ((count = reader.read(buffer)) != -1) response.append(buffer, 0, count);
                }

                JSONObject release = new JSONObject(response.toString());
                String latestVersion = normalizeVersion(release.optString("tag_name"));
                String releaseUrl = release.optString("html_url");
                if (latestVersion.isEmpty() || releaseUrl.isEmpty()) {
                    throw new IllegalStateException("最新版本信息不完整");
                }
                boolean hasUpdate = compareVersions(latestVersion, currentVersion) > 0;
                runOnUiThread(() -> showUpdateResult(button, currentVersion, latestVersion,
                        releaseUrl, hasUpdate));
            } catch (Exception error) {
                runOnUiThread(() -> {
                    if (isFinishing() || isDestroyed()) return;
                    resetUpdateButton(button);
                    toast("检查更新失败：" + error.getMessage());
                });
            } finally {
                if (connection != null) connection.disconnect();
            }
        });
    }

    private void showUpdateResult(Button button, String currentVersion, String latestVersion,
                                  String releaseUrl, boolean hasUpdate) {
        if (isFinishing() || isDestroyed()) return;
        resetUpdateButton(button);
        AlertDialog.Builder dialog = new AlertDialog.Builder(this);
        if (hasUpdate) {
            dialog.setTitle("发现新版本 v" + latestVersion)
                    .setMessage("当前版本：v" + currentVersion + "\n最新版本：v" + latestVersion)
                    .setNegativeButton("稍后", null)
                    .setPositiveButton("前往下载", (ignored, which) -> openUrl(releaseUrl));
        } else {
            dialog.setTitle("已是最新版本")
                    .setMessage("当前版本：v" + currentVersion)
                    .setPositiveButton("确定", null);
        }
        dialog.show();
    }

    private void resetUpdateButton(Button button) {
        button.setEnabled(true);
        button.setText("检查更新");
    }

    private void openUrl(String url) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (Exception error) {
            toast("无法打开下载页面");
        }
    }

    private String currentVersion() {
        try {
            String version = getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
            return version == null || version.trim().isEmpty() ? "未知" : normalizeVersion(version);
        } catch (PackageManager.NameNotFoundException ignored) {
            return "未知";
        }
    }

    private String coreVersion() {
        String tag = getString(R.string.vnt_core_tag).trim();
        if (tag.isEmpty() || tag.equalsIgnoreCase("unknown")) return "未知";
        return tag.startsWith("v") || tag.startsWith("V") ? tag : "v" + tag;
    }

    private static String normalizeVersion(String version) {
        String normalized = version == null ? "" : version.trim();
        if (normalized.startsWith("v") || normalized.startsWith("V")) {
            return normalized.substring(1);
        }
        return normalized;
    }

    private static int compareVersions(String candidate, String current) {
        String[] candidateParts = normalizeVersion(candidate).split("[-+]", 2)[0].split("\\.");
        String[] currentParts = normalizeVersion(current).split("[-+]", 2)[0].split("\\.");
        int length = Math.max(candidateParts.length, currentParts.length);
        try {
            for (int i = 0; i < length; i++) {
                int candidatePart = i < candidateParts.length ? Integer.parseInt(candidateParts[i]) : 0;
                int currentPart = i < currentParts.length ? Integer.parseInt(currentParts[i]) : 0;
                if (candidatePart != currentPart) return Integer.compare(candidatePart, currentPart);
            }
            return 0;
        } catch (NumberFormatException ignored) {
            return normalizeVersion(candidate).equalsIgnoreCase(normalizeVersion(current)) ? 0 : 1;
        }
    }

    private void editProfile(VntConfigStore.Profile existing) {
        JSONObject config = existing == null ? new JSONObject() : existing.config();
        LinearLayout form = column();
        form.setPadding(dp(20), dp(8), dp(20), dp(12));

        sectionHeader(form, "基础配置");
        EditText name = field(form, "配置名称", existing == null ? "" : existing.name, false, "例如：我的组网");
        EditText code = field(form, "网络编号 *", config.optString("network_code"), false, "相同编号的设备组成同一个虚拟网");
        ListInput servers = new ListInput(form, "服务器地址（支持 quic:// tcp:// wss:// dynamic://）",
                "例如：quic://1.2.3.4:29872", "＋ 添加服务器", toList(config.optJSONArray("server")));

        sectionHeader(form, "网络设置");
        EditText ip = field(form, "自定义虚拟 IP（可选）", config.optString("ip"), false, "例如：10.26.0.2");
        EditText mtu = field(form, "MTU", String.valueOf(config.optInt("mtu", 1380)), false, "1380");
        mtu.setInputType(InputType.TYPE_CLASS_NUMBER);
        EditText tunnelPort = field(form, "隧道端口（P2P 通信）",
                config.has("tunnel_port") ? String.valueOf(config.optInt("tunnel_port")) : "", false, "留空或 0 为自动分配");
        tunnelPort.setInputType(InputType.TYPE_CLASS_NUMBER);

        sectionHeader(form, "传输优化");
        CheckBox rtx = toggle(form, "QUIC 传输优化", "优化重传丢包", config.optBoolean("rtx"));
        CheckBox fec = toggle(form, "FEC 前向纠错", "损失部分带宽提升稳定性", config.optBoolean("fec"));
        CheckBox compress = toggle(form, "LZ4 压缩", "减少传输数据量", config.optBoolean("compress"));
        CheckBox noPunch = toggle(form, "关闭 P2P 打洞", "仅通过服务器中转", config.optBoolean("no_punch"));

        sectionHeader(form, "安全配置");
        EditText password = field(form, "组网加密密码", config.optString("password"), true, "留空则不加密，同一组网密码需相同");
        String savedCertMode = config.optString("cert_mode", "skip");
        String savedFingerprint = "";
        if (savedCertMode.startsWith("finger:")) {
            savedFingerprint = savedCertMode.substring(7);
            savedCertMode = "finger";
        }
        form.addView(text("服务端证书校验", 12, true, textBody()), top(12));
        Spinner certMode = new Spinner(this);
        certMode.setAdapter(spinnerAdapter(new String[]{"跳过验证（默认）", "系统证书验证", "证书指纹验证"}));
        certMode.setSelection(savedCertMode.equals("standard") ? 1 : savedCertMode.equals("finger") ? 2 : 0);
        form.addView(spinnerBox(certMode), top(6));
        TextView fingerprintLabel = text("证书指纹（服务端启动日志会输出）", 12, true, textBody());
        EditText fingerprint = input(savedFingerprint, false, "例如：3bdd8675606837cdf95d5e13445606315762315a78555f9da652940a25feaec1");
        LinearLayout.LayoutParams fingerprintLabelParams = top(12);
        form.addView(fingerprintLabel, fingerprintLabelParams);
        form.addView(fingerprint, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        boolean fingerSelected = certMode.getSelectedItemPosition() == 2;
        fingerprintLabel.setVisibility(fingerSelected ? View.VISIBLE : View.GONE);
        fingerprint.setVisibility(fingerSelected ? View.VISIBLE : View.GONE);
        certMode.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                int visibility = position == 2 ? View.VISIBLE : View.GONE;
                fingerprintLabel.setVisibility(visibility);
                fingerprint.setVisibility(visibility);
            }
            @Override public void onNothingSelected(AdapterView<?> parent) { }
        });

        sectionHeader(form, "NAT 与路由（点对网）");
        ListInput inputRoutes = new ListInput(form, "入栈网段（格式：CIDR,目标IP）",
                "例如：192.168.0.0/24,10.26.0.2", "＋ 添加入栈网段", toList(config.optJSONArray("input")));
        ListInput outputRoutes = new ListInput(form, "出栈网段（允许转发的网段）",
                "例如：0.0.0.0/0", "＋ 添加出栈网段", toList(config.optJSONArray("output")));
        CheckBox noTun = toggle(form, "关闭 TUN 网卡", "仅作流量出口或端口映射",
                "no".equals(config.optString("device_mode", "tun")));

        sectionHeader(form, "端口映射");
        ListInput portMappings = new ListInput(form, "映射规则（协议://监听地址-虚拟IP-目标地址）",
                "例如：tcp://0.0.0.0:81-10.0.0.2-10.0.0.2:80", "＋ 添加映射规则", toList(config.optJSONArray("port_mapping")));
        CheckBox allowMapping = toggle(form, "允许作为映射出口", "允许其他设备使用本机作跳板来进行端口映射", config.optBoolean("allow_mapping"));

        sectionHeader(form, "设备配置");
        EditText device = field(form, "设备名称", config.optString("device_name", Build.MODEL), false, "默认为手机型号");
        EditText deviceId = field(form, "设备 ID", config.optString("device_id", store.deviceId()), false, "不同设备不能相同");

        sectionHeader(form, "STUN 配置（高级，不填使用默认）");
        ListInput udpStuns = new ListInput(form, "UDP STUN 服务器",
                "例如：stun.l.google.com:19302", "＋ 添加 UDP STUN", toList(config.optJSONArray("udp_stun")));
        ListInput tcpStuns = new ListInput(form, "TCP STUN 服务器",
                "例如：stun.nextcloud.com:443", "＋ 添加 TCP STUN", toList(config.optJSONArray("tcp_stun")));

        ScrollView scroll = new ScrollView(this);
        scroll.addView(form);
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(existing == null ? "新建组网配置" : "编辑组网配置")
                .setView(scroll)
                .setNegativeButton("取消", null)
                .setPositiveButton("保存", null)
                .create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
            try {
                int mtuValue = Integer.parseInt(mtu.getText().toString().trim());
                int certPosition = certMode.getSelectedItemPosition();
                String certValue = certPosition == 1 ? "standard" : certPosition == 2
                        ? "finger:" + fingerprint.getText().toString().trim() : "skip";
                if (certPosition == 2 && fingerprint.getText().toString().trim().isEmpty()) {
                    toast("请填写证书指纹");
                    return;
                }
                VntConfigStore.Profile profile = VntConfigStore.Profile.create(name.getText().toString(), servers.joined(),
                        code.getText().toString(), password.getText().toString(), deviceId.getText().toString(), device.getText().toString(), ip.getText().toString(),
                        mtuValue, compress.isChecked(), rtx.isChecked(), fec.isChecked(), noPunch.isChecked(), noTun.isChecked(), outputRoutes.joined(),
                        inputRoutes.joined(), certValue, tunnelPort.getText().toString(),
                        portMappings.joined(), allowMapping.isChecked(), udpStuns.joined(), tcpStuns.joined());
                if (existing != null) profile = profile.withId(existing.id);
                store.save(profile);
                dialog.dismiss();
                render();
            } catch (Exception error) { toast(error.getMessage() == null ? "配置内容无效" : error.getMessage()); }
        }));
        dialog.show();
        // 表单较长，全屏展示，与 web 端大弹窗的编辑体验一致
        if (dialog.getWindow() != null) dialog.getWindow().setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    }

    private void requestVpn(VntConfigStore.Profile profile) {
        if ("no".equals(profile.config().optString("device_mode", "tun"))) {
            VntVpnService.start(this, profile);
            return;
        }
        pendingProfile = profile;
        Intent prepare = VpnService.prepare(this);
        if (prepare == null) {
            VntVpnService.start(this, profile);
            pendingProfile = null;
        } else vpnPermission.launch(prepare);
    }

    private void confirmStop() {
        new AlertDialog.Builder(this).setTitle("停止组网").setMessage("确定要停止当前 VNT 虚拟网络吗？")
                .setNegativeButton("取消", null).setPositiveButton("停止", (d, w) -> VntVpnService.stop(this)).show();
    }

    private EditText field(LinearLayout form, String label, String value, boolean password, String hint) {
        form.addView(text(label, 12, true, textBody()), top(12));
        EditText field = input(value, password, hint);
        form.addView(field, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        return field;
    }

    private EditText input(String value, boolean password, String hint) {
        EditText field = new EditText(this);
        field.setText(value);
        if (hint != null) field.setHint(hint);
        field.setTextSize(14);
        field.setTextColor(textStrong());
        field.setHintTextColor(textMuted());
        field.setSingleLine(true);
        if (password) field.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        field.setPadding(dp(12), dp(9), dp(12), dp(9));
        field.setBackground(round(bgInput(), 9, border(), 1));
        return field;
    }

    private void sectionHeader(LinearLayout form, String value) {
        form.addView(text(value, 15, true, INDIGO), top(22));
    }

    /** 与输入框同风格的下拉框适配器：文字配色与内边距跟随当前主题。 */
    private ArrayAdapter<String> spinnerAdapter(String[] items) {
        return new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, items) {
            @Override public View getView(int position, View convertView, ViewGroup parent) {
                TextView view = (TextView) super.getView(position, convertView, parent);
                view.setTextSize(14);
                view.setTextColor(textStrong());
                view.setSingleLine(true);
                view.setGravity(Gravity.CENTER_VERTICAL);
                view.setPadding(dp(14), 0, dp(36), 0);
                view.setBackgroundColor(Color.TRANSPARENT);
                return view;
            }

            @Override public View getDropDownView(int position, View convertView, ViewGroup parent) {
                TextView view = (TextView) super.getDropDownView(position, convertView, parent);
                view.setTextSize(14);
                view.setTextColor(textStrong());
                view.setSingleLine(true);
                view.setGravity(Gravity.CENTER_VERTICAL);
                view.setPadding(dp(14), dp(12), dp(14), dp(12));
                return view;
            }
        };
    }

    /** 圆角边框容器 + 右侧箭头，替代 Spinner 默认样式。 */
    private FrameLayout spinnerBox(Spinner spinner) {
        FrameLayout box = new FrameLayout(this);
        box.setBackground(round(bgInput(), 9, border(), 1));
        spinner.setBackgroundColor(Color.TRANSPARENT);
        spinner.setPopupBackgroundDrawable(round(bgHeader(), 9, border(), 1));
        box.addView(spinner, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(44)));
        TextView arrow = text("▾", 13, false, textMuted());
        FrameLayout.LayoutParams arrowParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.END | Gravity.CENTER_VERTICAL);
        arrowParams.rightMargin = dp(14);
        box.addView(arrow, arrowParams);
        return box;
    }

    private CheckBox toggle(LinearLayout form, String title, String description, boolean checked) {
        LinearLayout rowLayout = row();
        rowLayout.setGravity(Gravity.CENTER_VERTICAL);
        rowLayout.setPadding(dp(12), dp(10), dp(12), dp(10));
        rowLayout.setBackground(round(bgInput(), 9, border(), 1));
        LinearLayout texts = column();
        texts.addView(text(title, 14, true, textStrong()));
        texts.addView(text(description, 11, false, textMuted()), top(3));
        rowLayout.addView(texts, weighted());
        CheckBox box = new CheckBox(this);
        box.setChecked(checked);
        rowLayout.addView(box);
        form.addView(rowLayout, top(9));
        return box;
    }

    private static List<String> toList(JSONArray array) {
        List<String> values = new ArrayList<>();
        if (array != null) {
            for (int i = 0; i < array.length(); i++) {
                String value = array.optString(i).trim();
                if (!value.isEmpty()) values.add(value);
            }
        }
        return values;
    }

    /** 动态列表输入：每行一个输入框，带删除按钮，底部有添加按钮，参照 vnt-web 的配置编辑器。 */
    private final class ListInput {
        private final String hint;
        private final LinearLayout rows;
        private final List<EditText> inputs = new ArrayList<>();

        ListInput(LinearLayout form, String label, String hint, String addLabel, List<String> initial) {
            this.hint = hint;
            form.addView(text(label, 12, true, textBody()), top(12));
            rows = column();
            form.addView(rows);
            for (String value : initial) addRow(value);
            if (initial.isEmpty()) addRow("");
            Button add = ghost(addLabel);
            add.setOnClickListener(v -> addRow(""));
            form.addView(add, top(8));
        }

        private void addRow(String value) {
            LinearLayout rowLayout = row();
            rowLayout.setGravity(Gravity.CENTER_VERTICAL);
            EditText field = input(value, false, hint);
            LinearLayout.LayoutParams fieldParams = weighted();
            rowLayout.addView(field, fieldParams);
            Button remove = ghost("✕");
            remove.setTextColor(RED);
            remove.setOnClickListener(v -> {
                rows.removeView(rowLayout);
                inputs.remove(field);
            });
            LinearLayout.LayoutParams removeParams = new LinearLayout.LayoutParams(dp(44), dp(44));
            removeParams.leftMargin = dp(8);
            rowLayout.addView(remove, removeParams);
            LinearLayout.LayoutParams rowParams = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            rowParams.topMargin = dp(8);
            rows.addView(rowLayout, rowParams);
            inputs.add(field);
        }

        String joined() {
            StringBuilder value = new StringBuilder();
            for (EditText field : inputs) {
                String item = field.getText().toString().trim();
                if (item.isEmpty()) continue;
                if (value.length() > 0) value.append('\n');
                value.append(item);
            }
            return value.toString();
        }
    }

    private void sectionTitle(String value) { pageHost.addView(text(value, 16, true, textStrong()), top(20)); }

    private void empty(String value) {
        TextView empty = text(value, 13, false, textMuted());
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dp(16), dp(38), dp(16), dp(38));
        empty.setBackground(round(bgCard(), 12, border(), 1));
        pageHost.addView(empty, top(14));
    }

    private LinearLayout statCard(String label, String value) {
        LinearLayout card = card();
        card.setPadding(dp(15), dp(15), dp(15), dp(15));
        card.addView(text(label, 12, true, textMuted()));
        card.addView(text(value, 23, true, textStrong()), top(7));
        return card;
    }

    private LinearLayout card() {
        LinearLayout card = column();
        card.setPadding(dp(18), dp(18), dp(18), dp(18));
        card.setBackground(round(bgCard(), 12, border(), 1));
        card.setElevation(dp(1));
        return card;
    }

    private TextView labelValue(String label, String value, int valueColor) {
        TextView text = text(label + ":  " + value, 13, false, textMuted());
        // A single text view keeps compact mobile cards readable; key values use the page accent elsewhere.
        if (label.equals("虚拟 IP") || label.equals("网络编号")) text.setTextColor(valueColor);
        return text;
    }

    private Button primary(String value) { return styledButton(value, INDIGO, Color.WHITE, 0); }
    private Button danger(String value) { return styledButton(value, RED, Color.WHITE, 0); }
    private Button ghost(String value) { return styledButton(value, bgInput(), textBody(), border()); }

    private Button styledButton(String value, int background, int foreground, int stroke) {
        Button button = new Button(this);
        button.setText(value);
        button.setTextSize(13);
        button.setTextColor(foreground);
        button.setAllCaps(false);
        button.setMinHeight(dp(40));
        button.setPadding(dp(14), 0, dp(14), 0);
        button.setBackground(round(background, 9, stroke, stroke == 0 ? 0 : 1));
        return button;
    }

    private Button iconButton(String value) {
        Button button = ghost(value);
        button.setTextSize(20);
        button.setPadding(0, 0, 0, 0);
        button.setBackgroundColor(Color.TRANSPARENT);
        return button;
    }

    private TextView chip(String value, int foreground, int background) {
        TextView chip = text(value, 11, true, foreground);
        chip.setGravity(Gravity.CENTER);
        chip.setPadding(dp(9), dp(5), dp(9), dp(5));
        chip.setBackground(round(background, 8, border(), 1));
        return chip;
    }

    private TextView text(String value, float size, boolean bold, int color) {
        TextView text = new TextView(this);
        text.setText(value);
        text.setTextSize(size);
        text.setTextColor(color);
        text.setTypeface(Typeface.create("sans", bold ? Typeface.BOLD : Typeface.NORMAL));
        return text;
    }

    private LinearLayout row() { LinearLayout value = new LinearLayout(this); value.setOrientation(LinearLayout.HORIZONTAL); return value; }
    private LinearLayout column() { LinearLayout value = new LinearLayout(this); value.setOrientation(LinearLayout.VERTICAL); return value; }

    private GradientDrawable round(int fill, int radius, int stroke, int strokeWidth) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fill);
        drawable.setCornerRadius(dp(radius));
        if (strokeWidth > 0) drawable.setStroke(dp(strokeWidth), stroke);
        return drawable;
    }

    private int bgPage() { return dark ? Color.rgb(2, 6, 23) : Color.rgb(248, 250, 252); }
    private int bgHeader() { return dark ? Color.rgb(15, 23, 42) : Color.WHITE; }
    private int bgCard() { return dark ? Color.rgb(15, 23, 42) : Color.WHITE; }
    private int bgInput() { return dark ? Color.rgb(30, 41, 59) : Color.WHITE; }
    private int bgChip() { return dark ? Color.rgb(30, 41, 59) : Color.rgb(248, 250, 252); }
    private int border() { return dark ? Color.rgb(51, 65, 85) : Color.rgb(226, 232, 240); }
    private int textStrong() { return dark ? Color.WHITE : Color.rgb(15, 23, 42); }
    private int textBody() { return dark ? Color.rgb(226, 232, 240) : Color.rgb(51, 65, 85); }
    private int textMuted() { return dark ? Color.rgb(148, 163, 184) : Color.rgb(100, 116, 139); }

    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
    private LinearLayout.LayoutParams size(int width, int height) { return new LinearLayout.LayoutParams(dp(width), dp(height)); }
    private LinearLayout.LayoutParams weighted() { return new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1); }
    private LinearLayout.LayoutParams weightedWithStart() { LinearLayout.LayoutParams p = weighted(); p.leftMargin = dp(12); return p; }
    private LinearLayout.LayoutParams top(int top) { LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); p.topMargin = dp(top); return p; }
    private LinearLayout.LayoutParams end(int end) { LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT); p.rightMargin = dp(end); return p; }
    private static int colorWithAlpha(int color, int alpha) { return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color)); }

    private static String statusLabel(VntState.Status status) {
        return switch (status) {
            case RUNNING -> "运行中";
            case STARTING -> "启动中";
            case STOPPING -> "停止中";
            case ERROR -> "连接失败";
            default -> "已停止";
        };
    }

    private static boolean isSessionActive(VntState.Status status) {
        return status == VntState.Status.STARTING || status == VntState.Status.RUNNING
                || status == VntState.Status.STOPPING;
    }

    private static String bytes(long value) {
        if (value < 1024) return value + " B";
        if (value < 1024L * 1024) return String.format(Locale.US, "%.1f KB", value / 1024d);
        if (value < 1024L * 1024 * 1024) return String.format(Locale.US, "%.1f MB", value / (1024d * 1024));
        return String.format(Locale.US, "%.1f GB", value / (1024d * 1024 * 1024));
    }

    private void toast(String message) { Toast.makeText(this, message, Toast.LENGTH_LONG).show(); }

    private enum Page {
        DASHBOARD("网络总览"), PEERS("在线设备"),
        ROUTES("路由表"), CONFIG("组网配置"), ABOUT("关于");
        final String title;
        Page(String title) { this.title = title; }
    }
}
