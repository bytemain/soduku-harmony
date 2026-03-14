import { hapTasks, OhosHapContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { hvigor, HvigorPlugin, HvigorNode } from '@ohos/hvigor';

/**
 * CI 环境下跳过 GenerateUnitTestResult 任务。
 *
 * hvigorw test 的任务链为：BuildUnitTestHook → UnitTestArkTS → GenerateUnitTestResult
 * GenerateUnitTestResult 通过 @ohos/coverage 中的 previewer 执行测试并收集结果，
 * 其中 findPort (portutil.js) 会查找 previewer 二进制文件。
 * CI 容器没有 previewer，findPort 返回 null 导致 null.toString() 崩溃。
 *
 * 通过 hvigor.nodesEvaluated 钩子，在所有节点配置完成、任务注册后，
 * 遍历 HAP 上下文的所有 target，将 GenerateUnitTestResult 替换为空操作。
 * hvigor 中 target 级别的任务名格式为 "{target}@{taskName}"。
 * 实际测试执行仍需本地 DevEco Studio 环境（含 previewer）。
 */
function skipTestExecutionInCI(): HvigorPlugin {
  return {
    pluginId: 'skipTestExecutionInCI',
    apply(node: HvigorNode) {
      if (!process.env.CI) {
        return;
      }
      hvigor.nodesEvaluated(() => {
        const hapContext = node.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext;
        hapContext.targets((target) => {
          const targetName = target.getTargetName();
          const taskName = `${targetName}@GenerateUnitTestResult`;
          const task = node.getTaskByName(taskName);
          if (task) {
            task.overrideAction(() => {
              console.log(`Skipping ${taskName}: no previewer available in CI`);
            });
          }
        });
      });
    }
  };
}

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [skipTestExecutionInCI()],
}
