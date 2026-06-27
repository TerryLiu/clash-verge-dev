# GitHub 推送拒绝问题排查

## 1. GH007：私有邮箱保护

### 现象

```
remote: error: GH007: Your push would publish a private email address.
To github.com:TerryLiu/clash-verge-dev.git
 ! [remote rejected] fix-ubuntu-close-icon -> fix-ubuntu-close-icon
   (push declined due to email privacy restrictions)
```

### 根因

提交中使用的邮箱在 GitHub 上被标记为私有。GitHub 的邮箱隐私保护会阻止推送包含私有邮箱的提交。

### 解决

去 [GitHub Email Settings](https://github.com/settings/emails)：

1. 勾选 **"Keep my email addresses private"**
2. GitHub 自动生成格式为 `ID+USERNAME@users.noreply.github.com` 的匿名邮箱
3. 将 git 配置改为该邮箱：

```bash
git config --global user.email "3073134+TerryLiu@users.noreply.github.com"
```

> **注意：** 匿名邮箱的格式是 `ID+USERNAME@users.noreply.github.com`，不是 `USERNAME@users.noreply.github.com`（后者无效，无法添加）。

### 修改已有提交的邮箱

```bash
# 用 rebase 修正 author 邮箱
git rebase --exec \
  "git commit --amend --no-edit --author=\"TerrrryLau <3073134+TerryLiu@users.noreply.github.com>\"" \
  origin/dev fix-ubuntu-close-icon
```

---

## 2. Non-fast-forward：分支分叉

### 现象

```
To github.com:TerryLiu/clash-verge-dev.git
 ! [rejected]  fix-ubuntu-close-icon -> fix-ubuntu-close-icon (non-fast-forward)
hint: Updates were rejected because the tip of your current branch is behind
hint: its remote counterpart.
```

### 根因

远程分支已存在提交，且与本地历史分叉（例如：之前的推送被 GH007 拒绝但远程部分提交已存在，或 git commit --amend 改变了 hash）。

### 解决

```bash
# 强制推送（安全版本）
git fetch origin refs/heads/<branch>:refs/remotes/origin/<branch>
git push --force-with-lease -u origin <branch>

# 如果 --force-with-lease 报 "stale info"，改用
git push --force -u origin <branch>
```

> `--force-with-lease` 需要远程跟踪引用正确。如果 fetch 后仍然 "stale info"，通常是因为 refspec 没有正确设置 tracking branch。

---

## 3. 附加问题

### locale 警告

```
manpath: can't set the locale; make sure $LC_* and $LANG are correct
```

Git 操作时偶尔伴随此警告，**不影响 push/pull/clone 功能**。修复方式：

```bash
# 在 ~/.zshrc 或 ~/.bashrc 中设置
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

### CI Workflow 待审批

PR 页面上显示 **"N workflows awaiting approval"**：

```
3 workflows awaiting approval
This workflow requires approval from a maintainer.
```

这是 GitHub 的安全机制。当 PR 来自 fork 或仓库开启了 `pull_request_target` 事件的审批要求时，需要仓库 maintainer 点击 **"Approve and run"** 才能运行 CI。

> 你是仓库 owner 的话，在 Actions 页面可以看到审批按钮。

### `git remote update` 的陷阱

```bash
git remote update origin
# * branch fix-ubuntu-close-icon -> FETCH_HEAD
```

`git remote update` 默认只将远程分支 fetch 到 `FETCH_HEAD`，**不创建或更新** `origin/<branch>` 跟踪引用。这会导致后续 `--force-with-lease` 报 "stale info"。

**正确做法：** 用 `git fetch` 并指定 refspec：

```bash
git fetch origin refs/heads/<branch>:refs/remotes/origin/<branch>
```

---

## 4. 快速诊断清单

| 错误码 | 含义 | 解决 |
|--------|------|------|
| GH007 | 私有邮箱 | 开启邮箱隐私，更新 git config |
| non-fast-forward | 分叉 | force push 或 pull --rebase |
| stale info | 跟踪信息过期 | 先 fetch 再 force push |

### 常用检查命令

```bash
# 查看当前分支状态
git status -sb

# 比较本地与远程
git log --oneline origin/<branch>..<branch>

# 查看提交作者邮箱
git log --format="%h %an <%ae>" origin/dev..HEAD
```
