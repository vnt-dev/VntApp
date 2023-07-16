package top.wherewego.switchapp;

import android.os.Bundle;
import android.widget.EditText;
import android.widget.Toast;

import com.google.gson.Gson;
import com.hjq.bar.OnTitleBarListener;
import com.hjq.bar.TitleBar;

import java.util.UUID;

import top.wherewego.switchapp.app.AppActivity;
import top.wherewego.switchapp.app.AppApplication;
import top.wherewego.switchapp.util.SPUtils;
import top.wherewego.switchjni.ConfigurationInfoBean;

public class AddActivity extends AppActivity {
    private TitleBar mTitleBar;
    private EditText mToken;
    private EditText mName;
    private EditText mDeviceId;
    private EditText mPassword;
    private EditText mServer;
    private EditText mServerAddress;

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
        mServerAddress = findViewById(R.id.et_add_server_address_value);
    }

    @Override
    protected void initData() {

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
        if (mServerAddress.getText().toString().trim().isEmpty()) {
            Toast.makeText(this, "NatServer不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        ConfigurationInfoBean configurationInfoBean = new ConfigurationInfoBean(
                mToken.getText().toString().trim(), mName.getText().toString().trim(), mDeviceId.getText().toString().trim(),
                mPassword.getText().toString().trim(), mServer.getText().toString().trim(), mServerAddress.getText().toString().trim()
        );

        String keyset = SPUtils.getString(getApplicationContext(), "keyset", "0");
        if (keyset.equals("0")) {
            SPUtils.putString(getApplicationContext(), "keyset", configurationInfoBean.getKey());
        } else {
            SPUtils.putString(getApplicationContext(), "keyset", keyset + "," + configurationInfoBean.getKey());
        }
        SPUtils.putString(getApplicationContext(), configurationInfoBean.getKey(), new Gson().toJson(configurationInfoBean));
        AppApplication.configList.add(configurationInfoBean);
        finish();
    }

}