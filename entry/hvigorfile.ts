import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { HvigorPlugin, HvigorNode } from '@ohos/hvigor';

/**
 * CI 环境下跳过 GenerateUnitTestResult 任务。
 *
 * hvigorw test 的任务链为：BuildUnitTestHook → UnitTestArkTS → GenerateUnitTestResult
 * GenerateUnitTestResult 通过 @ohos/coverage 中的 previewer 执行测试并收集结果，
 * 其中 findPort (portutil.js) 会查找 previewer 二进制文件。
 * CI 容器没有 previewer，findPort 返回 null 导致 null.toString() 崩溃。
 *
 * 通过 afterNodeEvaluate 钩子拦截该任务，在 CI 环境下替换为空操作，
 * 使 hvigorw test 仅验证编译通过（UnitTestArkTS）而不尝试执行测试。
 * 实际测试执行仍需本地 DevEco Studio 环境（含 previewer）。
 */
function skipTestExecutionInCI(): HvigorPlugin {
  return {
    pluginId: 'skipTestExecutionInCI',
    apply(node: HvigorNode) {
      if (process.env.CI) {
        node.afterNodeEvaluate((evaluatedNode: HvigorNode) => {
          const task = evaluatedNode.getTaskByName('GenerateUnitTestResult');
          if (task) {
            task.overrideAction(() => {
              console.log('Skipping GenerateUnitTestResult: no previewer available in CI');
            });
          }
        });
      }
    }
  };
}

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [skipTestExecutionInCI()],
}
