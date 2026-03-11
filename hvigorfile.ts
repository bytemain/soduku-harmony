import { appTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

// Load signing config from data.json if it exists, otherwise fall back to environment variables
let fileData: { signingConfig?: object } | null = null;
const dataPath = path.resolve(__dirname, './data.json');
if (fs.existsSync(dataPath)) {
  fileData = require(dataPath);
}

const signingConfig = getSigningConfig();

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [],       /* Custom plugin to extend the functionality of Hvigor. */
  config: {
    ohos: {
      overrides: {
        ...(signingConfig ? { signingConfig } : {}),
        appOpt: {
          versionCode: getVersionCode(),
          versionName: getVersionName(),
        }
      }
    }
  }
}


function getSigningConfig() {
  // Prefer data.json if available
  if (fileData?.signingConfig) {
    return {
      type: "HarmonyOS",
      material: fileData.signingConfig,
    };
  }

  // Fall back to environment variables
  const certFile = process.env.SIGNING_CERT;
  const profileFile = process.env.SIGNING_PROFILE;
  const keyFile = process.env.SIGNING_KEY;
  const keyPwd = process.env.KEY_PASSWORD;
  const storePassword = process.env.KEYSTORE_PASSWORD;

  if (certFile && profileFile && keyFile) {
    return {
      type: "HarmonyOS",
      material: {
        certpath: certFile,
        profile: profileFile,
        keyAlias: "ide_demo_app",
        keyPwd,
        signAlg: "SHA256withECDSA",
        storeFile: keyFile,
        storePassword,
      },
    };
  }

  // No signing config available — produce an unsigned build
  return null;
}

function getVersionCode() {
  return 100000;
}

function getVersionName() {
  return "1";
}
