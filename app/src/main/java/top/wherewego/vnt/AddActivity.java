package top.wherewego.vnt;

import android.widget.EditText;
import android.widget.Spinner;
import android.widget.Toast;

import com.google.gson.Gson;
import com.hjq.bar.OnTitleBarListener;
import com.hjq.bar.TitleBar;

import java.util.UUID;

import top.wherewego.vnt.app.AppActivity;
import top.wherewego.vnt.app.AppApplication;
import top.wherewego.vnt.util.SPUtils;
import top.wherewego.vnt.jni.ConfigurationInfoBean;

public class AddActivity extends AppActivity {
    private TitleBar mTitleBar;
    private EditText mToken;
    private EditText mName;
    private EditText mDeviceId;
    private EditText mPassword;
    private EditText mServer;
    private EditText mStun;
    private Spinner mCipherModel;
    private Spinner mConnectType;
    private Spinner mFinger;

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
        mStun = findViewById(R.id.et_add_stun_value);
        mCipherModel = findViewById(R.id.et_add_cipher_model_value);
        mConnectType = findViewById(R.id.et_add_connect_type_value);
        mFinger = findViewById(R.id.et_add_finger_value);
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
        if (mStun.getText().toString().trim().isEmpty()) {
            Toast.makeText(this, "stun不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        String cipherModel = mCipherModel.getSelectedItem().toString().trim();
        String connectType = mConnectType.getSelectedItem().toString().trim();
        String finger = mFinger.getSelectedItem().toString().trim();
        ConfigurationInfoBean configurationInfoBean = new ConfigurationInfoBean(
                mToken.getText().toString().trim(), mName.getText().toString().trim(), mDeviceId.getText().toString().trim(),
                mPassword.getText().toString().trim(), mServer.getText().toString().trim(), mStun.getText().toString().trim(),
                cipherModel, "TCP".equalsIgnoreCase(connectType),"OPEN".equalsIgnoreCase(finger)
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