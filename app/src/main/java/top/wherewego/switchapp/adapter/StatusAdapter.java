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
        private final TextView mTokenValue;
        private final TextView mNameValue;
        private final TextView mServerValue;


        private ViewHolder() {
            super(R.layout.status_config_info_item);

            mTokenValue = findViewById(R.id.tv_info_token_value);
            mNameValue = findViewById(R.id.tv_info_name_value);
            mServerValue = findViewById(R.id.tv_info_server_value);
        }

        @Override
        public void onBindView(int position) {
            mTokenValue.setText(getItem(position).getToken());
            mNameValue.setText(getItem(position).getName());
            mServerValue.setText(getItem(position).getServer());
        }
    }
}