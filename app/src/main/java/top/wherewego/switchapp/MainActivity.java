package top.wherewego.switchapp;

import android.content.Intent;
import android.util.Log;
import android.view.View;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.hjq.bar.OnTitleBarListener;
import com.hjq.bar.TitleBar;
import com.scwang.smart.refresh.layout.SmartRefreshLayout;
import com.scwang.smart.refresh.layout.api.RefreshLayout;
import com.scwang.smart.refresh.layout.listener.OnRefreshLoadMoreListener;

import top.wherewego.base.BaseAdapter;
import top.wherewego.switchapp.adapter.StatusAdapter;
import top.wherewego.switchapp.app.AppActivity;
import top.wherewego.switchapp.app.AppApplication;
import top.wherewego.switchjni.ConfigurationInfoBean;
import top.wherewego.widget.layout.WrapRecyclerView;


public class MainActivity extends AppActivity implements OnRefreshLoadMoreListener,
        BaseAdapter.OnItemClickListener {
    static {
        System.loadLibrary("switch_jni");
    }

    private TitleBar mTitleBar;
    private SmartRefreshLayout mRefreshLayout;
    private WrapRecyclerView mRecyclerView;

    private StatusAdapter mAdapter;

    private ActivityResultLauncher<Intent> vpnLauncher;
    ConfigurationInfoBean selectConfigurationInfoBean;
    @Override
    protected int getLayoutId() {
        return R.layout.activity_main;
    }

    @Override
    protected void initView() {
        mTitleBar = findViewById(R.id.rb_main);
        mTitleBar.setOnTitleBarListener(new OnTitleBarListener() {
            @Override
            public void onRightClick(TitleBar titleBar) {
                startActivity(new Intent(getContext(), AddActivity.class));
            }
        });
        mRefreshLayout = findViewById(R.id.rl_status_refresh);
        mRecyclerView = findViewById(R.id.rv_status_list);

        mAdapter = new StatusAdapter(this);
        mAdapter.setOnItemClickListener(this);
        mRecyclerView.setAdapter(mAdapter);

        mRefreshLayout.setOnRefreshLoadMoreListener(this);
        vpnLauncher = registerForActivityResult(new ActivityResultContracts.StartActivityForResult(),
                result -> {
                    if (result.getResultCode() == RESULT_OK) {
                        // 用户已经授予所需权限，启动 VPN 服务
                        connect();
                    }
                });
    }

    @Override
    protected void initData() {
        //analogData();
        mAdapter.setData(AppApplication.configList);
    }

    @Override
    protected void onResume() {
        super.onResume();
        mAdapter.setData(AppApplication.configList);
        mRefreshLayout.finishRefresh();
    }

    @Override
    public void onItemClick(RecyclerView recyclerView, View itemView, int position) {
        selectConfigurationInfoBean = mAdapter.getItem(position);
        Intent vpnIntent = MyVpnService.prepare(this);
        if (vpnIntent != null) {
            vpnLauncher.launch(vpnIntent);
        } else {
            // 如果应用已经具备所需权限，直接启动 VPN 服务
            connect();
        }
    }
    private void connect(){
        Intent intent = new Intent(this, ConnectActivity.class);
        intent.putExtra("selectConfigurationInfoBean", selectConfigurationInfoBean);
        startActivity(intent);
    }

    @Override
    public void onRefresh(@NonNull RefreshLayout refreshLayout) {
        postDelayed(() -> {
            mAdapter.setData(AppApplication.configList);
            mRefreshLayout.finishRefresh();
        }, 1000);
    }

    @Override
    public void onLoadMore(@NonNull RefreshLayout refreshLayout) {
    }
}