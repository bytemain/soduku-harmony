import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { hvigor, HvigorPlugin, HvigorNode } from '@ohos/hvigor';

/**
 * 仅在显式要求“只编译测试”时禁用 GenerateUnitTestResult。
 *
 * hvigorw test 的任务链为：BuildUnitTestHook → UnitTestArkTS → GenerateUnitTestResult
 * GenerateUnitTestResult 通过 @ohos/coverage 中的 previewer 执行测试并收集结果，
 * 其中 findPort (portutil.js) 会查找 previewer 二进制文件。
 * Linux CI 容器没有 previewer，无法执行原生单测。
 *
 * 通过 hvigor.nodesEvaluated 钩子，在所有节点配置完成、任务注册后，
 * 使用 getTaskByName + setEnable(false) 禁用该任务。
 * hvigor 中 target 级别的任务名格式为 "{target}@{taskName}"。
 * 设置 HYPIUM_COMPILE_ONLY=1 只验证编译，不能视为测试通过。
 * 其他环境（包括配置了 DevEco 的 CI）默认执行测试；
 * 使用 node scripts/run-hypium-tests.mjs 同时检查用例结果，不能只看构建返回码。
 */
function compileTestsOnlyWhenRequested(): HvigorPlugin {
  return {
    pluginId: 'compileTestsOnlyWhenRequested',
    apply(node: HvigorNode) {
      if (process.env.HYPIUM_COMPILE_ONLY !== '1') {
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
            console.warn(`[HYPIUM COMPILE ONLY] Disabled ${taskName}; tests were NOT executed.`);
          }
        }
      });
    }
  };
}

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [compileTestsOnlyWhenRequested()],
}
