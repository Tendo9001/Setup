# Tendo's Windows Dev Setup

一键自动安装 Windows 开发环境，适合新手小白使用。

---

## 快速开始

### 第一步：以管理员身份打开 PowerShell

1. 按 **Windows 键**，搜索 `PowerShell`
2. 右键点击 **Windows PowerShell**
3. 选择 **以管理员身份运行**
4. 弹出询问视窗时，点 **是**

> 必须用管理员身份，否则部分安装步骤会失败。

---

### 第二步：复制贴上以下指令，按 Enter

```powershell
Set-ExecutionPolicy Bypass -Scope Process; iex (irm https://raw.githubusercontent.com/Tendo9001/Setup/main/win/bootstrap.ps1)
```

> **注意：** 必须整行复制，不能换行。在 PowerShell 视窗里按右键即可贴上。

---

### 第三步：等待安装完成（约 5~15 分钟）

脚本会自动完成以下步骤：

1. 安装 Git
2. 下载安装脚本
3. 安装所有软件和工具
4. 配置 VS Code 扩展
5. 设置 Git 用户名和邮箱（会提示你输入）

---

### 第四步：填写 Git 资料

安装过程中会出现提示，输入你的资料：

```
Enter your Git username: 你的名字
Enter your Git email:    你的邮箱
```

---

### 如果出现"需要重启"提示

Docker 需要开启虚拟化功能，第一次可能需要重启电脑：

```
========================================
  RESTART REQUIRED
========================================
After restarting, run this script again to install Docker Desktop.
```

遇到这种情况：
1. **重启电脑**
2. 再次以管理员身份打开 PowerShell
3. **重新运行第二步的指令**，会自动补装 Docker

---

## 安装内容

| 软件 | 用途 |
|------|------|
| Python 3.12 | 编程语言 |
| Node.js | JavaScript 执行环境 |
| Git | 版本控制 |
| Docker Desktop | 容器化工具 |
| VS Code | 代码编辑器 |
| Windows Terminal | 更好用的终端 |
| Google Chrome | 浏览器 |
| 7-Zip | 压缩/解压工具 |
| GitHub CLI | 在终端操作 GitHub |
| Claude Code | AI 编程助手 |

VS Code 扩展：
- **Cline** — AI 编程助手
- **Remote SSH** — 远程连接服务器

---

## 安装完成确认

安装结束后会显示已安装的版本：

```
Installed versions:
   Python: Python 3.12.x
   Node:   v22.x.x
   Git:    git version 2.x.x
   Docker: Docker version x.x.x
```

看到这个就代表成功了！

---

## 常见问题

**Q: 出现 "winget not found" 错误？**
前往 Microsoft Store 搜索并安装 **App Installer**，安装完后重新运行指令。

**Q: 某个软件安装失败了怎么办？**
脚本会显示警告但继续安装其余软件，之后可以用 `winget install <软件ID>` 单独安装失败的部分。

**Q: 安装完 Docker 但打不开？**
确认电脑已开启虚拟化，在 PowerShell 运行：
```powershell
Get-ComputerInfo -Property HyperVisorPresent
```

---

## 适用系统

- Windows 10 (version 1903 或以上)
- Windows 11

> 不支援 macOS 或 Linux。
