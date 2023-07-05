package top.wherewego.switchapp.ui.home;

import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ListView;

import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;

import java.util.ArrayList;
import java.util.List;

import top.wherewego.switchapp.R;
import top.wherewego.switchapp.databinding.FragmentHomeBinding;

public class HomeFragment extends Fragment {

    private FragmentHomeBinding binding;

    public View onCreateView(@NonNull LayoutInflater inflater,
                             ViewGroup container, Bundle savedInstanceState) {

        binding = FragmentHomeBinding.inflate(inflater, container, false);
        List<Element> elements = new ArrayList<>();
        elements.add(new Element("John", "address", "123456789012345678901234567890", "123 Main St"));
        elements.add(new Element("John", "address", "token", "123 Main St"));
        elements.add(new Element("John", "address", "token", "123 Main St"));
        binding.listView.setAdapter(new HomeListAdapter(getActivity(), R.layout.list_item, elements));
        return binding.getRoot();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}