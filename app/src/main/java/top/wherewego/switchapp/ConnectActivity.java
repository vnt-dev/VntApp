package top.wherewego.switchapp;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.RecyclerView;

import android.os.Bundle;
import android.view.View;
import android.widget.TextView;

import com.hjq.bar.OnTitleBarListener;
import com.hjq.bar.TitleBar;
import com.scwang.smart.refresh.layout.SmartRefreshLayout;
import com.scwang.smart.refresh.layout.api.RefreshLayout;
import com.scwang.smart.refresh.layout.listener.OnRefreshLoadMoreListener;

import java.util.ArrayList;
import java.util.List;

import top.wherewego.base.BaseAdapter;
import top.wherewego.switchapp.adapter.ConnectAdapter;
import top.wherewego.switchapp.adapter.StatusAdapter;
import top.wherewego.switchapp.app.AppActivity;
import top.wherewego.switchjni.ConfigurationInfoBean;
import top.wherewego.switchjni.DeviceBean;
import top.wherewego.widget.layout.WrapRecyclerView;


public class ConnectActivity extends AppActivity implements OnRefreshLoadMoreListener,
        BaseAdapter.OnItemClickListener{

    private TitleBar mTitleBar;
    private SmartRefreshLayout mRefreshLayout;
    private WrapRecyclerView mRecyclerView;

    private ConnectAdapter mAdapter;

    @Override
    protected int getLayoutId() {
        return R.layout.activity_connect;
    }

    @Override
    protected void initView() {
        ConfigurationInfoBean selectConfigurationInfoBean=(ConfigurationInfoBean)getIntent().getSerializableExtra("selectConfigurationInfoBean");
        mTitleBar = findViewById(R.id.tb_connect);
        mRefreshLayout = findViewById(R.id.rl_connect);
        mRecyclerView = findViewById(R.id.rv_connect_list);

        mAdapter = new ConnectAdapter(this);
        mAdapter.setOnItemClickListener(this);
        mRecyclerView.setAdapter(mAdapter);

        TextView headerView = mRecyclerView.addHeaderView(R.layout.picker_item);

        headerView.setText("Token:"+selectConfigurationInfoBean.getToken()+"   Name:"+selectConfigurationInfoBean.getName()+
                "\nDeviceID:"+selectConfigurationInfoBean.getDeviceId()+"   Password:"+selectConfigurationInfoBean.getPassword()+
                "\nServer:"+selectConfigurationInfoBean.getServer()+"   ServerAddress:"+selectConfigurationInfoBean.getServerAddress());
        mRefreshLayout.setOnRefreshLoadMoreListener(this);

        mTitleBar.setOnTitleBarListener(new OnTitleBarListener() {
            @Override
            public void onLeftClick(TitleBar titleBar) {
                finish();
            }
        });

    }

    @Override
    protected void initData() {
        mAdapter.setData(analogData());
    }

    /**
     * 模拟数据
     */
    private List<DeviceBean> analogData() {
        List<DeviceBean> data = new ArrayList<>();
        data.add(new DeviceBean("c9fef77549804aa0b1b9c08ce","127.0.0.1","offline","123456",""));
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