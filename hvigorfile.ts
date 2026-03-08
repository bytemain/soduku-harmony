import { appTasks } from '@ohos/hvigor-ohos-plugin';
import * as data from "./data.json"

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [],       /* Custom plugin to extend the functionality of Hvigor. */
  config: {
    ohos: {
      overrides:{
        signingConfig: getSigningConfig(), //签名配置对象
        appOpt: {
          versionCode: getVersionCode(),
          versionName: getVersionName(),
        }
      }
    }
  }
}


function getSigningConfig() {
  return {
    type: "HarmonyOS",
    material: data.signingConfig,
  }

}

function getVersionCode() {

  return 100000;

}

function getVersionName() {
  return "1";
}
