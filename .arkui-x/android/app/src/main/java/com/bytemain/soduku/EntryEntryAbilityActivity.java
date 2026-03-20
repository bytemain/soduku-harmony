package com.bytemain.soduku;

import android.os.Bundle;
import android.util.Log;

import ohos.stage.ability.adapter.StageActivity;

/**
 * ArkUI-X Android Activity 入口
 * 继承 StageActivity，加载 ArkUI 跨平台页面
 *
 * setInstanceName 格式: "{bundleName}:{moduleName}:{abilityName}:"
 * 需要与 module.json5 中的 ability 配置对应
 */
public class EntryEntryAbilityActivity extends StageActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.i("ArkUI-X", "EntryEntryAbilityActivity onCreate");
        setInstanceName("com.bytemain.soduku:entry:EntryAbility:");
        super.onCreate(savedInstanceState);
    }
}
