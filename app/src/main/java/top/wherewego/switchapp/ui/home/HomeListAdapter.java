package top.wherewego.switchapp.ui.home;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;

import top.wherewego.switchapp.R;

public class HomeListAdapter extends ArrayAdapter<Element> {
    private LayoutInflater inflater;
    private int resource;
    public HomeListAdapter(@NonNull Context context, int resource, @NonNull List<Element> objects) {
        super(context, resource, objects);
        this.resource = resource;
        this.inflater = LayoutInflater.from(context);
    }

    @NonNull
    @Override
    public View getView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
        ViewHolder viewHolder;

        if (convertView == null) {
            convertView = inflater.inflate(resource, parent, false);

            viewHolder = new ViewHolder();
            viewHolder.textViewServer = convertView.findViewById(R.id.item_server);
            viewHolder.textViewToken = convertView.findViewById(R.id.item_token);
            viewHolder.textViewName = convertView.findViewById(R.id.item_name);

            convertView.setTag(viewHolder);
        } else {
            viewHolder = (ViewHolder) convertView.getTag();
        }
        Element element = getItem(position);
        if (element != null) {
            viewHolder.textViewServer.setText(element.getServerAddress());
            viewHolder.textViewToken.setText(element.getToken());
            viewHolder.textViewName.setText(element.getName());
        }

        return convertView;
    }
    private static class ViewHolder {
        TextView textViewServer;
        TextView textViewToken;
        TextView textViewName;
    }
}
