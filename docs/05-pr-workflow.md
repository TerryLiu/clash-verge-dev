# PR 工作流：从创建到合并

本文档覆盖 PR 创建、描述编写、CI 审批以及合并阻塞的常见问题。

---

## 1. 创建 PR

### 方式一：推送后 GitHub 页面创建

```bash
git push -u origin <branch>
```

推送后访问仓库页面，GitHub 会显示 **"Compare & pull request"** 按钮，或直接访问：

```
https://github.com/<owner>/<repo>/compare/<base>...<branch>
```

### 方式二：gh CLI

```bash
gh pr create --base dev --head fix-ubuntu-close-icon \
  --title "fix: Linux custom titlebar close button unclickable" \
  --body "$(cat pr_body.md)"
```

---

## 2. PR 描述模板

一个清晰的 PR 描述应包含以下部分：

```markdown
## 问题
<描述修复的问题或实现的功能>

## 根因
<如果是 bug 修复，说明根本原因>

## 修复
<说明具体改了什么，为什么这样改>

## 变更文件

| 文件 | 说明 |
|------|------|
| `src/components/layout/window-controller.tsx` | 添加 xxx，修复 xxx |
| `.gitignore` | 添加 `builder/` 目录 |

## 测试

- [x] <场景1> 验证通过
- [x] <场景2> 不影响其他平台
```

### 真实示例

```
标题：fix: Linux custom titlebar close button unclickable

## 问题
在 Linux (WebKitGTK) 下，窗口自定义标题栏的关闭、最小化、最大化三个按钮无法响应点击事件。

## 根因
Tauri 在 Linux/WebKitGTK 下，data-tauri-drag-region 拖拽区域的事件会渗透到子元素，
拦截了按钮的点击事件。

## 修复
在按钮容器上添加 data-tauri-drag-region="false"，显式排除拖拽区域，
确保按钮点击事件正常触发。同时将按钮鼠标样式从 default 改为 pointer。

## 变更文件
| 文件 | 说明 |
|------|------|
| src/components/layout/window-controller.tsx | 添加 data-tauri-drag-region="false" |
| .gitignore | 添加 builder/ 目录 |
```

---

## 3. PR 页面检查项

创建 PR 后，页面会显示各种检查状态：

### Checks 状态

| 图标 | 含义 |
|------|------|
| 🟢 Successful | 通过 |
| 🟡 In progress / Pending | 运行中或排队 |
| 🔴 Failed | 失败，需修复 |
| ⚪ Neutral | 跳过（如 approval 未通过） |

### PR AI Slop Review

本项目配置了 `PR AI Slop Review` 工作流，分为三个阶段：

```
PR AI Slop Review / pre_activation (pull_request_target)   🟢 Successful
PR AI Slop Review / activation (pull_request_target)       🟢 Successful
PR AI Slop Review / agent (pull_request_target)            🟡 In progress
```

`agent` 阶段是 AI 代码评审，完成后方可合并。

### Workflow 待审批

**现象：** 页面显示 "N workflows awaiting approval"。

**原因：** 仓库开启了对外部贡献者的 workflow 审批。首次贡献或使用 `pull_request_target` 事件的 workflow 需要 maintainer 手动批准。

**解决：** 仓库 maintainer 在 PR 的 "Checks" 标签页或 Actions 页面点击 **"Approve and run"**。

---

## 4. 合并阻塞

### Merging is blocked

常见阻塞原因：

| 阻塞文本 | 原因 | 解决文档 |
|----------|------|----------|
| **Commits must have verified signatures** | 提交未 GPG 签名 | [04-gpg-verified-commits-setup.md](04-gpg-verified-commits-setup.md) |
| **Required status check failed** | CI 未通过 | 查看 Checks 标签修复 |
| **Review required** | 缺少 maintainer 审批 | 请求 review |
| **This branch has conflicts** | 与 base 分支冲突 | `git merge origin/dev` 并解决冲突 |

### 冲突解决

```bash
git fetch origin dev
git merge origin/dev
# 解决冲突后
git add .
git commit -S -m "chore: resolve merge conflicts"
git push
```

---

## 5. PR 生命周期

```
创建 PR → CI 运行 → AI Review → 人工 Review → 解决反馈 → 合并
```

- **Draft PR：** 标记为 WIP，CR 前自检
- **Ready for review：** 完成 Draft，请求 review
- **Close / Reopen：** 关闭不合并 / 重新打开继续讨论
