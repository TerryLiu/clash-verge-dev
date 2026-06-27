# Git & GitHub 问题排查记录 — 索引

本系列记录了 `clash-verge-dev` 项目在一次 PR 流程中解决的全部问题。

## 文档目录

| 编号 | 文档 | 内容 |
|------|------|------|
| 01 | [Git Remote 与代理配置](01-git-remote-and-proxy.md) | Remote HTTPS→SSH、HTTP/SSH 代理区别、`gitssh` 别名 |
| 02 | [Husky Hooks VSCode 修复](02-husky-hooks-vscode-fix.md) | PATH 缺失、钩子调用链、rebase 恢复命令 |
| 03 | [推送拒绝排查](03-github-push-troubleshooting.md) | GH007、non-fast-forward、locale、CI 审批 |
| 04 | [GPG 签名配置](04-gpg-verified-commits-setup.md) | 密钥生成、Git 配置、常见错误案例 |
| 05 | [PR 工作流](05-pr-workflow.md) | PR 描述模板、CI 检查、合并阻塞排查 |

## 核心原则

- **GPG 签名：** `GPG 密钥邮箱 = git commit 邮箱 = GitHub 验证邮箱`（三者必须一致）
- **Husky PATH：** VSCode 不加载 `.zshrc`，需在 `.husky/_/h` 中显式设置
- **SSH 代理：** SSH 协议不读 `http_proxy`，必须用 `ProxyCommand`

## 快速检查清单

推送 PR 前确认：

- [ ] `git remote -v` 使用 SSH
- [ ] `.husky/_/h` 包含 nvm + cargo PATH
- [ ] `git config user.email` 匹配 GitHub no-reply 邮箱（`ID+USERNAME@users.noreply.github.com`）
- [ ] GPG 密钥已上传 GitHub，`git log --show-signature` 全部显示"完好的签名"
- [ ] PR 描述包含问题、根因、修复、测试
