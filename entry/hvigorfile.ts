import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { hvigor, HvigorPlugin, HvigorNode } from '@ohos/hvigor';

/**
 * CI 环境下禁用 GenerateUnitTestResult 任务。
 *
 * hvigorw test 的任务链为：BuildUnitTestHook → UnitTestArkTS → GenerateUnitTestResult
 * GenerateUnitTestResult 通过 @ohos/coverage 中的 previewer 执行测试并收集结果，
 * 其中 findPort (portutil.js) 会查找 previewer 二进制文件。
 * CI 容器没有 previewer，findPort 返回 null 导致 null.toString() 崩溃。
 *
 * 通过 hvigor.nodesEvaluated 钩子，在所有节点配置完成、任务注册后，
 * 使用 getTaskByName + setEnable(false) 禁用该任务。
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
        // Disable GenerateUnitTestResult for all build targets.
        // Task names are target-scoped: "{target}@GenerateUnitTestResult".
        const targets: string[] = ['default', 'ohosTest'];
        for (const target of targets) {
          const taskName = `${target}@GenerateUnitTestResult`;
          const task = node.getTaskByName(taskName);
          if (task) {
            task.setEnable(false);
            console.log(`[CI] Disabled task: ${taskName}`);
          }
        }
      });
    }
  };
}

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [skipTestExecutionInCI()],
}
