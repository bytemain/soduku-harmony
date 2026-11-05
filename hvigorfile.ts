import { appTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

interface SigningMaterial {
  certpath?: string;
  profile?: string;
  storeFile?: string;
  keyAlias?: string;
  keyPassword?: string;
  keyPwd?: string; // Legacy data.json spelling, normalized before passing to Hvigor.
  storePassword?: string;
  signAlg?: string;
}

function getSigningConfig() {
  // Used by unsigned builds before the official SDK signing step.
  if (process.env.SIGNING_DISABLED === '1') {
    return null;
  }

  const dataPath = process.env.SIGNING_CONFIG_FILE || path.resolve(__dirname, './data.json');
  let material: SigningMaterial | undefined;
  if (fs.existsSync(dataPath)) {
    let data: { signingConfig?: SigningMaterial };
    try {
      data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
    } catch (_) {
      throw new Error('Signing configuration is not readable valid JSON.');
    }
    material = data.signingConfig;
    if (!material) {
      throw new Error('Signing configuration must contain a signingConfig material object.');
    }
  } else if (process.env.SIGNING_CONFIG_FILE) {
    throw new Error('SIGNING_CONFIG_FILE does not exist.');
  }

  if (!material) {
    const signingRequested = process.env.SIGNING_REQUIRED === '1' ||
      ['SIGNING_CERT', 'SIGNING_PROFILE', 'SIGNING_KEY', 'SIGNING_KEY_ALIAS',
       'KEY_PASSWORD', 'KEYSTORE_PASSWORD'].some(name => process.env[name] !== undefined);
    if (!signingRequested) {
      return null;
    }
    material = {
      certpath: process.env.SIGNING_CERT,
      profile: process.env.SIGNING_PROFILE,
      storeFile: process.env.SIGNING_KEY,
      keyAlias: process.env.SIGNING_KEY_ALIAS || 'ide_demo_app',
      keyPassword: process.env.KEY_PASSWORD,
      storePassword: process.env.KEYSTORE_PASSWORD,
      signAlg: 'SHA256withECDSA',
    };
  }

  // Official Hvigor schema uses keyPassword; hap-sign-tool's CLI uses keyPwd.
  const normalized = {
    certpath: material.certpath,
    profile: material.profile,
    storeFile: material.storeFile,
    keyAlias: material.keyAlias || process.env.SIGNING_KEY_ALIAS || 'ide_demo_app',
    keyPassword: material.keyPassword || material.keyPwd,
    storePassword: material.storePassword,
    signAlg: material.signAlg || 'SHA256withECDSA',
  };
  const missing = Object.keys(normalized).filter(name =>
    typeof normalized[name as keyof typeof normalized] !== 'string' ||
    normalized[name as keyof typeof normalized]!.length === 0);
  if (missing.length) {
    throw new Error(`Incomplete signing material: ${missing.join(', ')}.`);
  }
  if (normalized.signAlg !== 'SHA256withECDSA') {
    throw new Error('This HarmonyOS signing configuration requires SHA256withECDSA.');
  }
  for (const name of ['certpath', 'profile', 'storeFile'] as const) {
    if (!fs.existsSync(normalized[name]!) || !fs.statSync(normalized[name]!).isFile()) {
      throw new Error(`Signing material file is missing: ${name}.`);
    }
  }
  // DevEco 26's official Hvigor decrypts these fields using material/{fd,ac,ce}.
  // Raw passwords (including long hex passwords) must use scripts/sign-release-app.py.
  const materialDir = path.join(path.dirname(normalized.storeFile!), 'material');
  const encryptedFields = [normalized.keyPassword!, normalized.storePassword!];
  if (!encryptedFields.every(value => /^[0-9a-fA-F]{32,}$/.test(value) && value.length % 2 === 0) ||
      !['fd', 'ac', 'ce'].every(name => {
        const item = path.join(materialDir, name);
        return fs.existsSync(item) && fs.statSync(item).isDirectory();
      })) {
    throw new Error('Hvigor requires DevEco-encrypted passwords and the matching material directory. For raw-password files, use scripts/sign-release-app.py.');
  }
  return { type: 'HarmonyOS', material: normalized };
}

const signingConfig = getSigningConfig();
export default {
  system: appTasks,
  plugins: [],
  config: {
    ohos: {
      overrides: {
        ...(signingConfig ? { signingConfig } : {}),
        // 版本统一读取 AppScope/app.json5。
      }
    }
  }
};
