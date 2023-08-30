package top.wherewego.vnt.adapter;

import android.content.Context;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;

import top.wherewego.vnt.R;
import top.wherewego.vnt.app.AppAdapter;
import top.wherewego.vnt.jni.DeviceBean;

public final class ConnectAdapter extends AppAdapter<DeviceBean> {
    public ConnectAdapter(Context context) {
        super(context);
    }

    @NonNull
    @Override
    public ConnectAdapter.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        return new ConnectAdapter.ViewHolder();
    }

    private final class ViewHolder extends AppAdapter<?>.ViewHolder {

//        private final TextView mName;
//        private final TextView mIp;
//        private final TextView mStatus;
//        private final TextView mRt;
//        private final TextView mContentType;

        private final TextView mNameValue;
        private final TextView mIpValue;
        private final TextView mStatusValue;
        private final TextView mRtValue;
        private final TextView mContentTypeValue;

        private ViewHolder() {
            super(R.layout.status_item);
//            mName = findViewById(R.id.tv_name);
//            mIp = findViewById(R.id.tv_ip);
//            mStatus = findViewById(R.id.tv_status);
//            mRt = findViewById(R.id.tv_rt);
//            mContentType = findViewById(R.id.tv_content_type);
            mNameValue = findViewById(R.id.tv_name_value);
            mIpValue = findViewById(R.id.tv_ip_value);
            mStatusValue = findViewById(R.id.tv_status_value);
            mRtValue = findViewById(R.id.tv_rt_value);
            mContentTypeValue = findViewById(R.id.tv_content_type_value);
        }

        @Override
        public void onBindView(int position) {
            mNameValue.setText(getItem(position).getName());
            mIpValue.setText(getItem(position).getIp());
            mStatusValue.setText(getItem(position).getStatus());
            mRtValue.setText(getItem(position).getRt());
            mContentTypeValue.setText(getItem(position).getConnectType());
        }
    }
}
