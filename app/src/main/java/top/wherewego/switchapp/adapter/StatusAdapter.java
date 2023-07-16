package top.wherewego.switchapp.adapter;

import android.content.Context;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;

import top.wherewego.switchapp.R;
import top.wherewego.switchapp.app.AppAdapter;
import top.wherewego.switchjni.ConfigurationInfoBean;

/**
 *    author : Android 轮子哥
 *    github : https://github.com/getActivity/AndroidProject
 *    time   : 2019/09/22
 *    desc   : 状态数据列表
 */
public final class StatusAdapter extends AppAdapter<ConfigurationInfoBean> {

    public StatusAdapter(Context context) {
        super(context);
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new ViewHolder();
    }

    private final class ViewHolder extends AppAdapter<?>.ViewHolder {

//        private final TextView mName;
//        private final TextView mIp;
//        private final TextView mStatus;
//        private final TextView mRt;
//        private final TextView mContentType;
//
//        private final TextView mNameValue;
//        private final TextView mIpValue;
//        private final TextView mStatusValue;
//        private final TextView mRtValue;
//        private final TextView mContentTypeValue;


        private final TextView mTokenValue;
        private final TextView mNameValue;
        private final TextView mDeviceIDValue;
        private final TextView mPasswordValue;
        private final TextView mServerValue;
        private final TextView mServerAddressValue;


        private ViewHolder() {
            super(R.layout.status_config_info_item);
//            mName = findViewById(R.id.tv_name);
//            mIp = findViewById(R.id.tv_ip);
//            mStatus = findViewById(R.id.tv_status);
//            mRt = findViewById(R.id.tv_rt);
//            mContentType = findViewById(R.id.tv_content_type);
//            mNameValue = findViewById(R.id.tv_name_value);
//            mIpValue = findViewById(R.id.tv_ip_value);
//            mStatusValue = findViewById(R.id.tv_status_value);
//            mRtValue = findViewById(R.id.tv_rt_value);
//            mContentTypeValue = findViewById(R.id.tv_content_type_value);

            mTokenValue = findViewById(R.id.tv_info_token_value);
            mNameValue = findViewById(R.id.tv_info_name_value);
            mDeviceIDValue = findViewById(R.id.tv_info_device_id_value);
            mPasswordValue = findViewById(R.id.tv_info_password_value);
            mServerValue = findViewById(R.id.tv_info_server_value);
            mServerAddressValue = findViewById(R.id.tv_info_server_address_value);
        }

        @Override
        public void onBindView(int position) {
            mTokenValue.setText(getItem(position).getToken());
            mNameValue.setText(getItem(position).getName());
            mDeviceIDValue.setText(getItem(position).getDeviceId());
            mPasswordValue.setText(getItem(position).getPassword());
            mServerValue.setText(getItem(position).getServer());
            mServerAddressValue.setText(getItem(position).getServerAddress());
        }
    }
}