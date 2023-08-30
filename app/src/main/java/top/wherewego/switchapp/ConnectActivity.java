package top.wherewego.switchapp;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.hjq.bar.OnTitleBarListener;
import com.hjq.bar.TitleBar;
import com.scwang.smart.refresh.layout.SmartRefreshLayout;
import com.scwang.smart.refresh.layout.api.RefreshLayout;
import com.scwang.smart.refresh.layout.listener.OnRefreshLoadMoreListener;

import java.util.ArrayList;
import java.util.List;

import top.wherewego.base.BaseAdapter;
import top.wherewego.switchapp.adapter.ConnectAdapter;
import top.wherewego.switchapp.app.AppActivity;
import top.wherewego.vnt.jni.ConfigurationInfoBean;
import top.wherewego.vnt.jni.DeviceBean;
import top.wherewego.widget.layout.WrapRecyclerView;


public class ConnectActivity extends AppActivity implements OnRefreshLoadMoreListener,
        BaseAdapter.OnItemClickListener {

    private TitleBar mTitleBar;
    private SmartRefreshLayout mRefreshLayout;
    private WrapRecyclerView mRecyclerView;
    @SuppressLint("StaticFieldLeak")
    public static TextView headerView;
    @SuppressLint("StaticFieldLeak")
    public static ConnectAdapter mAdapter;
    ConfigurationInfoBean selectConfigurationInfoBean;
    @Override
    protected int getLayoutId() {
        return R.layout.activity_connect;
    }

    @Override
    protected void initView() {
        selectConfigurationInfoBean = (ConfigurationInfoBean) getIntent().getSerializableExtra("selectConfigurationInfoBean");
        mTitleBar = findViewById(R.id.tb_connect);
        mRefreshLayout = findViewById(R.id.rl_connect);
        mRecyclerView = findViewById(R.id.rv_connect_list);

        mAdapter = new ConnectAdapter(this);
        mAdapter.setOnItemClickListener(this);
        mRecyclerView.setAdapter(mAdapter);

        headerView = mRecyclerView.addHeaderView(R.layout.picker_item);


        mRefreshLayout.setOnRefreshLoadMoreListener(this);

        mTitleBar.setOnTitleBarListener(new OnTitleBarListener() {
            @Override
            public void onLeftClick(TitleBar titleBar) {
                finish();
            }
        });
        startMyVpnService();
    }

    @Override
    public void finish() {
        super.finish();
        MyVpnService.stop();

    }

    /**
     * 启动服务
     */
    private void startMyVpnService() {
        if (MyVpnService.isStart()) {
            Toast.makeText(this, "服务已经启动", Toast.LENGTH_SHORT).show();
            return;
        }
        String token = selectConfigurationInfoBean.getToken().trim();
        String deviceId = selectConfigurationInfoBean.getDeviceId().trim();
        String name = selectConfigurationInfoBean.getName().trim();
        String server = selectConfigurationInfoBean.getServer().trim();
        String stun = selectConfigurationInfoBean.getStun().trim();
        String password = selectConfigurationInfoBean.getPassword().trim();
        String cipherModel = selectConfigurationInfoBean.getCipherModel().trim();
        boolean isTcp = selectConfigurationInfoBean.isTcp();
        if (token.isEmpty()) {
            Toast.makeText(this, "Token不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (deviceId.isEmpty()) {
            Toast.makeText(this, "DeviceId不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (name.isEmpty()) {
            Toast.makeText(this, "Name不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (server.isEmpty()) {
            Toast.makeText(this, "ServerAddress不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (stun.isEmpty()) {
            Toast.makeText(this, "Stun不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (cipherModel.isEmpty()){
            Toast.makeText(this, "加密模式不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        String[] parts = server.split(":");
        if (parts.length != 2) {
            Toast.makeText(this, "服务器地址错误", Toast.LENGTH_SHORT).show();
            return;
        }
        int port = 0;
        try {
            port = Integer.parseInt(parts[1]);
        } catch (Exception ignored) {
        }
        if (port <= 0 || port >= 65536) {
            Toast.makeText(this, "ServerAddress error", Toast.LENGTH_SHORT).show();
            return;
        }
        Intent serviceIntent = new Intent(this, MyVpnService.class);
        serviceIntent.setAction("start");
        serviceIntent.putExtra("token", token);
        serviceIntent.putExtra("deviceId", deviceId);
        serviceIntent.putExtra("name", name);
        serviceIntent.putExtra("server", server);
        serviceIntent.putExtra("stunServer", stun);
        serviceIntent.putExtra("password",password);
        serviceIntent.putExtra("cipherModel",cipherModel);
        serviceIntent.putExtra("isTcp",isTcp);
        startService(serviceIntent);
    }

    @Override
    protected void initData() {
//        mAdapter.setData(analogData());
    }

    /**
     * 模拟数据
     */
    private List<DeviceBean> analogData() {
        List<DeviceBean> data = new ArrayList<>();
        data.add(new DeviceBean("c9fef77549804aa0b1b9c08ce", "127.0.0.1", "offline", "123456", ""));
        return data;
    }

    @Override
    public void onLoadMore(@NonNull RefreshLayout refreshLayout) {

    }

    @Override
    public void onRefresh(@NonNull RefreshLayout refreshLayout) {

    }

    @Override
    public void onItemClick(RecyclerView recyclerView, View itemView, int position) {

    }
}