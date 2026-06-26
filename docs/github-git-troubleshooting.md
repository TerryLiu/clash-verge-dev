# GitHub Git 提交与推送问题排查记录

本文档记录了 `clash-verge-dev` 项目在一次 PR 流程中遇到的一系列 Git 问题及解决方案。

---

## 1. Git Remote: HTTPS → SSH

**问题：** 需要将仓库远程地址从 HTTPS 切换为 SSH。

**解决：**

```bash
git remote set-url origin git@github.com:TerryLiu/clash-verge-dev.git
```

验证：
```bash
git remote -v
# origin  git@github.com:TerryLiu/clash-verge-dev.git (fetch)
# origin  git@github.com:TerryLiu/clash-verge-dev.git (push)
```

---

## 2. VSCode 提交时 Husky Pre-commit Hook 失败

**现象：** 终端可以正常 `git commit`，但从 VSCode 的 Git GUI 提交时报错，提示 `cargo-make` 或 `pnpm` 找不到。

**根因：** 项目使用 Husky 管理 Git 钩子（`core.hookspath=.husky/_`），`.husky/pre-commit` 需要 `cargo-make` 和 `pnpm`。VSCode 从桌面启动时不会加载 shell 配置文件（`.zshrc` / `.bashrc`），导致 `~/.cargo/bin` 和 nvm 的 Node.js 路径不在 PATH 中。

**解决：** 编辑 `.husky/_/h`，在脚本中显式加载 nvm 并添加 cargo 路径：

```bash
# .husky/_/h 第 16-18 行
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export PATH="$HOME/.cargo/bin:node_modules/.bin:$PATH"
```

此后无论是终端还是 VSCode IDE 触发的 Git 操作，钩子都能正常找到所需命令。

---

## 3. GitHub 拒绝推送：私有邮箱保护（GH007）

**现象：**

```
remote: error: GH007: Your push would publish a private email address.
 ! [remote rejected] fix-ubuntu-close-icon -> fix-ubuntu-close-icon
   (push declined due to email privacy restrictions)
```

**根因：** 提交中使用的邮箱 `cqliuz@gmail.com` 在 GitHub 上被标记为私有。

**解决：** 在 GitHub [Email Settings](https://github.com/settings/emails) 中开启 **"Keep my email addresses private"**，启用以 `@users.noreply.github.com` 结尾的匿名邮箱。

---

## 4. 强制推送：Non-fast-forward 拒绝

**现象：**

```
! [rejected]  fix-ubuntu-close-icon -> fix-ubuntu-close-icon (non-fast-forward)
```

**根因：** 远程分支已存在旧提交，本地历史与之分叉。

**解决：**

```bash
# 如果远程版本是旧的/错误的，使用强制推送覆盖
git fetch origin refs/heads/fix-ubuntu-close-icon:refs/remotes/origin/fix-ubuntu-close-icon
git push --force -u origin fix-ubuntu-close-icon
```

> 注意：`--force-with-lease` 在远程跟踪引用不完整时会报 "stale info"，此时需先正确 fetch 或改用 `--force`。

---

## 5. GPG 提交签名配置

**问题：** 仓库要求 "Commits must have verified signatures"，合并被阻塞。

### 5.1 生成 GPG 密钥

```bash
# 注意：邮箱必须与 git commit 使用的邮箱一致
gpg --batch --passphrase '' --quick-generate-key \
  "TerrrryLau <3073134+TerryLiu@users.noreply.github.com>" ed25519 sign 1d
```

### 5.2 查看密钥 ID

```bash
gpg --list-secret-keys --keyid-format LONG
```

### 5.3 配置 Git 自动签名

```bash
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
git config --global user.email "3073134+TerryLiu@users.noreply.github.com"
```

### 5.4 将公钥添加到 GitHub

```bash
gpg --armor --export <KEY_ID>
```

将输出的公钥粘贴到 [GitHub GPG Settings](https://github.com/settings/gpg/new)。

### 5.5 重新签名已有提交

```bash
# 跳过钩子，重新签名分支上所有提交
HUSKY=0 git rebase --exec "git commit --amend -S --no-edit" origin/dev fix-ubuntu-close-icon
git push --force -u origin fix-ubuntu-close-icon
```

---

## 6. GPG 签名仍显示 Unverified

**现象：** 提交已签名，但 GitHub 上仍显示 "Unverified"。

**根因分析：**

| 检查项 | 说明 |
|--------|------|
| GPG 密钥已上传到 GitHub | 必须 |
| GPG 密钥邮箱 = 提交 author 邮箱 | **必须完全一致** |
| 该邮箱在 GitHub 已验证 | 必须 |

### 我们遇到的坑

**第一次：** GPG 密钥邮箱用的是 `cqliuz@gmail.com`，但提交邮箱变成了 `TerrrryLau@users.noreply.github.com` → 不匹配。

**第二次：** 用 `TerrrryLau@users.noreply.github.com` 生成新密钥，但这不是 GitHub 的正确格式。真正的 no-reply 邮箱是 `3073134+TerryLiu@users.noreply.github.com`（GitHub 会自动生成 `ID+USERNAME` 格式）。

**最终正确做法：**

1. 先去 GitHub Email Settings 开启隐私保护，确认实际地址
2. 用正确地址生成 GPG 密钥
3. 确保 `git config user.email`、GPG 密钥 UID、GitHub 验证邮箱三者完全一致

---

## 7. Vigilant Mode（警惕模式）

在 GitHub [Settings → S/MIME & GPG keys](https://github.com/settings/keys) 中有一个 "Vigilant mode" 选项：

- **不开启：** 未签名的提交不显示任何标记
- **开启后：** 任何归属你账户但未 GPG 签名的提交会主动显示 ⚠️ "Unverified"

> 如果开启，历史未签名提交也会被标记，可能导致旧 PR 合并受阻。谨慎启用。

---

## 快速检查清单

在推送 PR 前确认：

- [ ] `git remote -v` 使用 SSH 地址
- [ ] `.husky/_/h` 包含 nvm 和 cargo 的 PATH 配置
- [ ] `git config user.email` 与 GitHub 验证邮箱一致
- [ ] GPG 密钥已生成并上传 GitHub
- [ ] GPG 密钥 UID 邮箱 = git config 邮箱 = GitHub 验证邮箱
- [ ] `git log --show-signature` 确认所有提交显示"完好的签名"
- [ ] 推送前确认远程分支状态，避免不必要的 force push
