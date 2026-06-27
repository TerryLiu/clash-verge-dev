# Husky Git Hooks 在 VSCode 中的 PATH 问题

## 现象

终端 `git commit` 正常运行，但 VSCode Git GUI 提交时报错：

```
❌ cargo-make is required for pre-commit checks.
❌ pnpm is required for pre-commit checks.
husky - pre-commit script failed (code 127)
husky - command not found in PATH=...
```

## 根因

项目使用 Husky 管理 Git 钩子，配置在 `.git/config` 中：

```
core.hookspath=.husky/_
```

调用链：`.git/hooks/` → `.husky/_/pre-commit`（桩）→ `.husky/_/h`（调度器）→ `.husky/pre-commit`（实际脚本）。

`.husky/pre-commit` 需要 `cargo-make`、`pnpm` 等命令，这些命令的路径（`~/.cargo/bin`、nvm 的 `node`/`pnpm`）只在终端 shell 配置文件（`.zshrc`）中设置。

VSCode 从桌面/GUI 启动时**不加载** `.zshrc`，导致 PATH 仅有系统默认路径，找不到这些命令。

## 解决

编辑 `.husky/_/h`，在脚本内显式加载 nvm 并添加 cargo 路径：

```bash
# .husky/_/h 第 16-18 行
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export PATH="$HOME/.cargo/bin:node_modules/.bin:$PATH"
```

### 修改前

```bash
export PATH="node_modules/.bin:$PATH"
```

### 修改后

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export PATH="$HOME/.cargo/bin:node_modules/.bin:$PATH"
```

## 验证

```bash
# 模拟 VSCode 最小 PATH 环境
PATH="/usr/bin:/bin" sh .husky/_/pre-commit

# 应正常完成：
# [cargo-make] INFO - Running Task: pre-commit
# [cargo-make] INFO - Build Done
```

## Pre-push Hook

`.husky/pre-push` 同样通过 `cargo make pre-push` 运行，首次推送或未设置 upstream 时会显示：

```
[cargo-make] INFO - Running Task: pre-push
No upstream found, skipping diff-based checks
[cargo-make] INFO - Build Done in 0.00 seconds.
```

这是正常行为，推送会继续。设置 upstream 后，pre-push 可以比较差异来执行增量检查。

## 跳过钩子（调试用）

```bash
# 环境变量方式（推荐，Husky 原生支持）
HUSKY=0 git commit -m "message"
HUSKY=0 git rebase --continue

# Git 原生方式
git commit --no-verify -m "message"
```

> 不推荐长期使用 `--no-verify`，会绕过格式化、lint 等检查。

## Rebase 中途钩子失败：恢复命令

当执行 `git rebase --exec` 时，如果 pre-commit hook 失败，rebase 会暂停。此时你有几个选项：

```bash
# 放弃整个 rebase，回到 rebase 前状态
git rebase --abort

# 修复问题后继续（如修改 .husky/_/h 后）
HUSKY=0 git rebase --continue

# 跳过当前提交（谨慎使用）
git rebase --skip
```

### 常见场景

```bash
# 场景：rebase --exec 时钩子失败，报 cargo-make not found
HUSKY=0 git rebase --continue
```

> 如果 `.husky/_/h` 已经修复好 PATH，后续步骤即使不用 `HUSKY=0` 也能正常通过。

## 相关文件

| 文件 | 作用 |
|------|------|
| `.husky/pre-commit` | 实际 pre-commit 脚本，调用 `cargo make pre-commit` |
| `.husky/pre-push` | pre-push 脚本 |
| `.husky/_/h` | Husky 调度器，负责 PATH 设置和脚本分发 |
| `.husky/_/pre-commit` | 桩脚本，转发到 `h` |
