package top.wherewego.switchapp;

import android.content.Intent;
import android.util.Log;
import android.view.View;
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
import top.wherewego.switchapp.adapter.StatusAdapter;
import top.wherewego.switchapp.app.AppActivity;
import top.wherewego.switchapp.app.AppApplication;
import top.wherewego.switchapp.util.SPUtils;
import top.wherewego.switchjni.ConfigurationInfoBean;
import top.wherewego.widget.layout.WrapRecyclerView;


public class MainActivity extends AppActivity implements OnRefreshLoadMoreListener,
        BaseAdapter.OnItemClickListener{
    static {
        System.loadLibrary("switch_jni");
    }

    private TitleBar mTitleBar;
    private SmartRefreshLayout mRefreshLayout;
    private WrapRecyclerView mRecyclerView;

    private StatusAdapter mAdapter;


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
                startActivity(new Intent(getContext(),AddActivity.class));
            }
        });
        mRefreshLayout = findViewById(R.id.rl_status_refresh);
        mRecyclerView = findViewById(R.id.rv_status_list);

        mAdapter = new StatusAdapter(this);
        mAdapter.setOnItemClickListener(this);
        mRecyclerView.setAdapter(mAdapter);

        mRefreshLayout.setOnRefreshLoadMoreListener(this);
    }

    @Override
    protected void initData() {
        //analogData();
        mAdapter.setData(AppApplication.configList);
    }

    /**
     * 模拟数据
     */
    private List<ConfigurationInfoBean> analogData() {
        List<ConfigurationInfoBean> data = new ArrayList<>();
        data.add(new ConfigurationInfoBean("lbl77889csc","huawei p60","1","123456","dy","127.0.0.1"));
        return data;
    }

    @Override
    protected void onResume() {
        super.onResume();
        List<ConfigurationInfoBean> list = new ArrayList<>();
        list = AppApplication.configList;

        mAdapter.setData(AppApplication.configList);
        Log.d("swichapp", "configList size "+ AppApplication.configList.size());
        mRefreshLayout.finishRefresh();
    }

    @Override
    public void onItemClick(RecyclerView recyclerView, View itemView, int position) {
        Toast.makeText(this,"点击了第"+mAdapter.getItem(position).getName(),Toast.LENGTH_LONG).show();
        Intent intent = new Intent(this,ConnectActivity.class);
        ConfigurationInfoBean selectConfigurationInfoBean = mAdapter.getItem(position);
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