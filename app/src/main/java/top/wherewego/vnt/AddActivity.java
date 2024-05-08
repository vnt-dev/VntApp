package top.wherewego.vnt;

import android.content.Intent;
import android.util.Log;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.SpinnerAdapter;
import android.widget.Toast;

import com.google.gson.Gson;
import com.hjq.bar.OnTitleBarListener;
import com.hjq.bar.TitleBar;

import java.util.ArrayList;
import java.util.Objects;
import java.util.UUID;

import top.wherewego.vnt.app.AppActivity;
import top.wherewego.vnt.app.AppApplication;
import top.wherewego.vnt.config.ConfigurationInfoBean;
import top.wherewego.vnt.util.SPUtils;

public class AddActivity extends AppActivity {
    private TitleBar mTitleBar;
    private EditText mToken;
    private EditText mName;
    private EditText mDeviceId;
    private EditText mPassword;
    private EditText mServer;
    private EditText mInIps;
    private EditText mOutIps;
    private Spinner mCipherModel;
    private Spinner mConnectType;
    private Spinner mFinger;
    private Spinner mPriority;

    private int position;

    @Override
    protected int getLayoutId() {
        return R.layout.activity_add;
    }

    @Override
    protected void initView() {
        mTitleBar = findViewById(R.id.tb_add);
        mTitleBar.setOnTitleBarListener(new OnTitleBarListener() {
            @Override
            public void onLeftClick(TitleBar titleBar) {
                finish();
            }

            @Override
            public void onRightClick(TitleBar titleBar) {
                save();
            }
        });

        mToken = findViewById(R.id.et_add_token_value);
        mName = findViewById(R.id.et_add_name_value);
        mName.setText(android.os.Build.MODEL);
        String id = SPUtils.getString(this.getContext(), "device-id", "");
        if (id == null || id.isEmpty()) {
            id = UUID.randomUUID().toString().replace("-", "");
            SPUtils.putString(this, "device-id", id);
        }
        mDeviceId = findViewById(R.id.et_add_device_id_value);
        mDeviceId.setText(id);
        mPassword = findViewById(R.id.et_add_password_value);
        mServer = findViewById(R.id.et_add_server_value);
//        mStun = findViewById(R.id.et_add_stun_value);
        mInIps = findViewById(R.id.et_add_in_ip_value);
        mOutIps = findViewById(R.id.et_add_out_ip_value);
        mCipherModel = findViewById(R.id.et_add_cipher_model_value);
        mConnectType = findViewById(R.id.et_add_connect_type_value);
        mFinger = findViewById(R.id.et_add_finger_value);
        mPriority = findViewById(R.id.et_add_priority_value);
//        mPort = findViewById(R.id.et_add_port_value);
    }


    public void setSpinnerItemSelectedByValue(Spinner spinner, String value) {
        SpinnerAdapter apsAdapter = spinner.getAdapter();
        int k = apsAdapter.getCount();
        for (int i = 0; i < k; i++) {
            if (value.equals(apsAdapter.getItem(i).toString())) {
                spinner.setSelection(i, true);// 默认选中项
                break;
            }
        }
    }

    public int findIndex(ArrayList<ConfigurationInfoBean> array, String target) {
        for (int i = 0; i < array.size(); i++) {
            if (Objects.equals(array.get(i).getToken(), target)) {
                return i;
            }
        }
        return -1;
    }


    private ConfigurationInfoBean getPrevConfigurationInfo() {
        try {
            return this.position > -1 ? AppApplication.configList.get(this.position) : null;
        } catch (Exception e) {
            return null;
        }
    }


    @Override
    protected void initData() {
        Intent intent = getIntent();
        this.position = intent.getIntExtra("position", -1);
        ConfigurationInfoBean configurationInfoBean = this.getPrevConfigurationInfo();
        if (configurationInfoBean != null) {
            this.mToken.setText(configurationInfoBean.getToken());
            this.mName.setText(configurationInfoBean.getName());
            this.mDeviceId.setText(configurationInfoBean.getDeviceId());
            this.mPassword.setText(configurationInfoBean.getPassword());
            this.mServer.setText(configurationInfoBean.getServer());
            if (configurationInfoBean.getInIps() != null) {
                this.mInIps.setText(String.join("\n", configurationInfoBean.getInIps()));
            }
            if (configurationInfoBean.getOutIps() != null) {
                this.mOutIps.setText(String.join("\n", configurationInfoBean.getOutIps()));
            }
            this.setSpinnerItemSelectedByValue(this.mCipherModel, configurationInfoBean.getCipherModel());
            this.setSpinnerItemSelectedByValue(this.mConnectType, configurationInfoBean.isTcp() ? "TCP" : "UDP");
            this.setSpinnerItemSelectedByValue(this.mFinger, configurationInfoBean.isFinger() ? "open" : "close");
            this.setSpinnerItemSelectedByValue(this.mPriority, configurationInfoBean.isFirstLatency() ? "latency" : "p2p");
        }
    }

    private void save() {
        if (mToken.getText().toString().trim().isEmpty()) {
            Toast.makeText(this, "token不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (mName.getText().toString().trim().isEmpty()) {
            Toast.makeText(this, "name不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (mDeviceId.getText().toString().trim().isEmpty()) {
            Toast.makeText(this, "DeviceId不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (mServer.getText().toString().trim().isEmpty()) {
            Toast.makeText(this, "Server不能为空", Toast.LENGTH_SHORT).show();
            return;
        }

        String token = mToken.getText().toString().trim();
        String name = mName.getText().toString().trim();
        String deviceId = mDeviceId.getText().toString().trim();
        String password = mPassword.getText().toString().trim();
        String server = mServer.getText().toString().trim();

        String cipherModel = mCipherModel.getSelectedItem().toString().trim();
        boolean isTcp = mConnectType.getSelectedItem().toString().trim().equalsIgnoreCase("tcp");
        boolean finger = mFinger.getSelectedItem().toString().trim().equalsIgnoreCase("open");
        boolean latency = mPriority.getSelectedItem().toString().trim().equalsIgnoreCase("latency");
        String inIps = mInIps.getText().toString().trim();
//        String portStr = mPort.getText().toString().trim();
//        if (!portStr.isEmpty()) {
//            try {
//                int port = Integer.parseInt(portStr);
//                if (port < 0 || port >= 65535) {
//                    Toast.makeText(this, "port错误", Toast.LENGTH_SHORT).show();
//                    return;
//                }
//            } catch (Exception e) {
//                Toast.makeText(this, "port错误", Toast.LENGTH_SHORT).show();
//                return;
//            }
//        }


        String outIps = mOutIps.getText().toString().trim();

        ConfigurationInfoBean bean;
        if (this.position < 0) {
            bean = new ConfigurationInfoBean();
        }else{
            bean =  AppApplication.configList.get(this.position);
        }
        bean.setToken(token);
        bean.setName(name);
        bean.setPassword(password);
        bean.setCipherModel(cipherModel);
        bean.setServerEncrypt(true);
        bean.setRelay(false);
        bean.setDeviceId(deviceId);
        bean.setServer(server);
        bean.setStunServer(new String[]{"stun1.l.google.com:19302","stun2.l.google.com:19302","stun.miwifi.com:3478"});
        bean.setTcp(isTcp);
        bean.setFinger(finger);
        bean.setFirstLatency(latency);
        if (!inIps.isEmpty()){
            bean.setInIps(inIps.split("\n"));
        }
        if (!outIps.isEmpty()){
            bean.setOutIps(outIps.split("\n"));
        }
        try {
            String err = check(bean);
            if (err != null) {
                Toast.makeText(this, err, Toast.LENGTH_SHORT).show();
                return;
            }
        } catch (Exception e) {
            Toast.makeText(this, e.getMessage(), Toast.LENGTH_SHORT).show();
            return;
        }

        if (this.position < 0) {
            bean.setKey(""+System.currentTimeMillis());
            AppApplication.configList.add(bean);
            //新增
            String keyset = SPUtils.getString(getApplicationContext(), "keyset", null);
            if (keyset==null) {
                SPUtils.putString(getApplicationContext(), "keyset", bean.getKey());
            } else {
                SPUtils.putString(getApplicationContext(), "keyset", keyset + "," + bean.getKey());
            }
        }

        SPUtils.putString(getApplicationContext(), bean.getKey(), new Gson().toJson(bean));

        finish();
    }

    String check(ConfigurationInfoBean configurationInfoBean) {
        String[] parts = configurationInfoBean.getServer().split(":");

        if (parts.length != 2) {
            return "服务器地址错误";
        }
        int port = 0;
        try {
            port = Integer.parseInt(parts[1]);
        } catch (Exception ignored) {
        }
        if (port <= 0 || port >= 65536) {
            return "服务端口错误";
        }
        return null;
    }

}
