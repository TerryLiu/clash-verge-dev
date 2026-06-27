# Git Remote 管理与代理配置

## 1. 切换 Remote：HTTPS → SSH

```bash
# 查看当前 remote
git remote -v

# 修改为 SSH
git remote set-url origin git@github.com:TerryLiu/clash-verge-dev.git
```

---

## 2. HTTP 代理 vs SSH 代理

### 核心区别

| | HTTP 协议克隆 | SSH 协议克隆 |
|------|------|------|
| 地址格式 | `https://github.com/user/repo.git` | `git@github.com:user/repo.git` |
| 端口 | 443 | 22 |
| 代理方式 | 读 `http_proxy` / `https_proxy` 环境变量 | **不读**环境变量，需 ProxyCommand 转发 |
| 设置方式 | `export https_proxy=...` | `GIT_SSH_COMMAND` 或 `~/.ssh/config` |

### 为什么 SSH 不走 HTTP 代理？

`http_proxy` / `https_proxy` 是 HTTP 协议层的环境变量，由 `curl`、`wget` 等 HTTP 客户端读取。Git 在处理 `https://` remote 时内部使用 `libcurl`，所以能自动走代理。

但 SSH 协议是另一套协议栈，它通过 `ssh` 命令建立连接，`ssh` 根本不认识 `http_proxy`。要让 SSH 流量过代理，必须用 `ProxyCommand` 将 SSH 的 TCP 连接包裹在代理协议中。

---

## 3. HTTP 代理设置（HTTPS Clone 用）

```bash
# 临时设置（当前终端有效）
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890    # SOCKS 代理，部分工具支持

# 设置后，HTTPS 协议的 git 操作自动走代理
git clone https://github.com/user/repo.git   # ✅ 走代理
git push                                       # ✅ 走代理

# 取消代理
unset http_proxy https_proxy all_proxy
```

> 如果 remote 是 `git@github.com:...`（SSH），设这些环境变量**无效**。

---

## 4. SSH 代理设置（SSH Clone 用）

### 前提

系统需安装 `nc`（netcat-openbsd）或 `ncat`（nmap）。

```bash
# 检查可用工具
which nc ncat
# nc 需要支持 -X connect 参数（netcat-openbsd 版本）
```

### 方案 A：Shell 别名（临时代理，推荐）

```bash
# 追加到 ~/.zshrc
alias gitssh='GIT_SSH_COMMAND="ssh -o ProxyCommand=\"nc -X connect -x 127.0.0.1:7890 %h %p\"" git'
```

用法：

```bash
# 普通 git 命令前加 gitssh 即可
gitssh clone git@github.com:user/repo.git
gitssh push
gitssh pull
gitssh fetch
```

- 只对当次命令生效
- 不影响其他终端或仓库
- 代理地址 `127.0.0.1:7890` 按实际情况修改

### 方案 B：SSH Config 别名（复用方便）

```bash
# ~/.ssh/config
Host github-proxy
    HostName github.com
    User git
    ProxyCommand nc -X connect -x 127.0.0.1:7890 %h %p
```

克隆时用别名：

```bash
git clone git@github-proxy:user/repo.git
```

### 方案 C：仓库级局部配置（用完即删）

```bash
cd repo
git config core.sshCommand "ssh -o ProxyCommand='nc -X connect -x 127.0.0.1:7890 %h %p'"
```

仅影响当前仓库，不污染全局设置。

### 补充：不同工具的 ProxyCommand

```bash
# netcat-openbsd (Linux 常见)
nc -X connect -x 127.0.0.1:7890 %h %p

# ncat (nmap)
ncat --proxy 127.0.0.1:7890 --proxy-type http %h %p

# connect-proxy
connect-proxy -H 127.0.0.1:7890 %h %p
```

---

## 5. 如何判断当前用的哪种协议？

```bash
git remote -v
# https://github.com/user/repo.git   → HTTPS，用 http_proxy
# git@github.com:user/repo.git       → SSH，用 GIT_SSH_COMMAND
```

---

## 6. 常用代理检查命令

```bash
# 查看当前代理环境变量
env | grep -i proxy

# 测试代理是否连通
curl -x http://127.0.0.1:7890 https://github.com -o /dev/null -w "%{http_code}\n"

# 测试 SSH（返回 "successfully authenticated" 但会关掉连接，说明通了）
ssh -T git@github.com
```
