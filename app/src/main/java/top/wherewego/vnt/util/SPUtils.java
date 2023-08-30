package top.wherewego.vnt.util;

import android.content.Context;
import android.content.SharedPreferences;

public class SPUtils {
    private static final String NAME = "config";
    //添加string对象
    public static void putString(Context context, String key, String value){
        SharedPreferences sp = context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        sp.edit().putString(key,value).commit();
    }
    //获取string对象
    public static String getString(Context context,String key,String defValue){
        SharedPreferences sp = context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        return sp.getString(key,defValue);
    }
    //添加int值
    public static void putInt(Context context,String key,int value){
        SharedPreferences sp = context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        sp.edit().putInt(key,value).commit();
    }
    //获取int值
    public static int getInt(Context context,String key,int defValue){
        SharedPreferences sp = context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        return sp.getInt(key,defValue);
    }
    //添加布尔对象
    public static void putBoolean(Context context,String key,Boolean value){
        SharedPreferences sp = context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        sp.edit().putBoolean(key,value).commit();
    }
    //获取布尔对象
    public static Boolean getBoolean(Context context,String key,Boolean defValue){
        SharedPreferences sp = context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        return sp.getBoolean(key,defValue);
    }

    //删除某个键值对
    public static void deleteShare(Context context,String key){
        SharedPreferences sp =  context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        sp.edit().remove(key).commit();
    }
    //删除所有键值对
    public static void deleteAll(Context context){
        SharedPreferences sp = context.getSharedPreferences(NAME,context.MODE_PRIVATE);
        sp.edit().clear().commit();
    }
}
