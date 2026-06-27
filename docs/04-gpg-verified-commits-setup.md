# GPG 提交签名配置指南

当 GitHub 仓库要求 "Commits must have verified signatures" 时，所有提交需用 GPG 签名。

## 核心原则

**GPG 密钥邮箱 = git commit 邮箱 = GitHub 验证邮箱 → 三者必须一致**

任何一环不匹配，GitHub 都会显示 "Unverified"。

---

## 1. 确认 GitHub 邮箱

先去 [GitHub Email Settings](https://github.com/settings/emails) 确认实际使用的邮箱：

- **公开邮箱：** 如 `cqliuz@gmail.com`
- **匿名邮箱：** 开启 "Keep my email addresses private" 后生成，格式为 `ID+USERNAME@users.noreply.github.com`（例 `3073134+TerryLiu@users.noreply.github.com`）

## 2. 生成 GPG 密钥

```bash
gpg --batch --passphrase '' --quick-generate-key \
  "TerrrryLau <3073134+TerryLiu@users.noreply.github.com>" \
  ed25519 sign 1d
```

> `ed25519` 是现代推荐算法，比 RSA 更小更快。`1d` 表示 1 天后过期（可调整）。

## 3. 查看密钥 ID

```bash
gpg --list-secret-keys --keyid-format LONG
```

输出示例：

```
sec   ed25519/2FA4A4CD9B3CAD94 2026-06-26 [SC]
uid                   [ 绝对 ] TerrrryLau <3073134+TerryLiu@users.noreply.github.com>
```

密钥 ID 为 `/` 后面的短 ID：`2FA4A4CD9B3CAD94`。

## 4. 上传公钥到 GitHub

```bash
gpg --armor --export 2FA4A4CD9B3CAD94
```

复制输出（含 `-----BEGIN PGP PUBLIC KEY BLOCK-----` 头尾），粘贴到：[https://github.com/settings/gpg/new](https://github.com/settings/gpg/new)。

## 5. 配置 Git 自动签名

```bash
git config --global user.signingkey 2FA4A4CD9B3CAD94
git config --global commit.gpgsign true
git config --global user.email "3073134+TerryLiu@users.noreply.github.com"
```

- `user.signingkey` — 指定签名用的 GPG 密钥
- `commit.gpgsign true` — 每次 commit 自动签名（无需手动加 `-S`）
- `user.email` — 必须与 GPG 密钥邮箱一致

## 6. 对已有提交重新签名

```bash
# 跳过钩子，重新签名分支上所有提交
HUSKY=0 git rebase \
  --exec "git commit --amend -S --no-edit --author=\"TerrrryLau <3073134+TerryLiu@users.noreply.github.com>\"" \
  origin/dev <branch>

# 推送
git push --force -u origin <branch>
```

## 7. 验证

本地验证：

```bash
git log --show-signature origin/dev..HEAD

# 输出应包含：
# gpg: 完好的签名，来自于 "TerrrryLau <3073134+TerryLiu@users.noreply.github.com>" [绝对]
```

GitHub 验证：刷新 PR 页面，提交旁应显示绿色 **"Verified"** 标记。

---

## 常见错误

### Unverified — 邮箱不匹配

| 检查项 | 命令 |
|--------|------|
| GPG 密钥邮箱 | `gpg --list-secret-keys --keyid-format LONG` |
| Git 提交邮箱 | `git log --format="%an <%ae>" origin/dev..HEAD` |
| Git 配置邮箱 | `git config user.email` |

三者必须完全一致。

### Unverified — GPG 公钥未上传

去 [GitHub GPG Settings](https://github.com/settings/gpg) 确认密钥已添加且未过期。

### Unverified — GitHub 邮箱未验证

去 [GitHub Email Settings](https://github.com/settings/emails) 确认该邮箱已添加且已验证。

---

## 错误案例记录

### 案例 1：GPG 密钥邮箱 ≠ 提交邮箱

- GPG 密钥：`cqliuz@gmail.com`
- 提交邮箱：`TerrrryLau@users.noreply.github.com`
- 结果：GitHub Unverified ❌

### 案例 2：错误的 no-reply 格式

- 以为匿名邮箱是 `TerrrryLau@users.noreply.github.com`
- 实际是 `3073134+TerryLiu@users.noreply.github.com`
- 结果：无法添加到 GitHub，"Email cannot add" ❌

### 案例 3：未开启隐私保护

- 直接用 `cqliuz@gmail.com` 提交
- 该邮箱在 GitHub 标记为私有
- 推送被 GH007 拒绝 ❌

---

## Vigilant Mode（警惕模式）

在 [GitHub Settings → S/MIME & GPG keys](https://github.com/settings/keys) 中：

- **开启后：** 任何归属你但未签名的提交会显示 Unverified
- **不开启：** 未签名提交无标记

> 开启会影响所有历史未签名提交，谨慎使用。
