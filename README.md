# 文件上传服务器

扫描二维码 → 上传文件 → 文件自动发送到指定邮箱

## 功能

- 扫码即用，无需安装 App
- 拖拽或点击上传文件
- 通过 163 SMTP 加密发送到邮箱
- 实时二维码显示当前访问地址
- 支持局域网内任何设备访问

## 快速开始

### 1. 获取 163 邮箱授权码

1. 登录 163 邮箱网页版（https://mail.163.com）
2. 进入「设置」→「POP3/SMTP/IMAP」
3. 开启 **SMTP 服务**
4. 按提示获取「**授权码**」（不是登录密码）

### 2. 配置

首次运行会自动生成 `config.json`，编辑并将授权码填入：

```json
{
  "smtpServer": "smtp.163.com",
  "smtpPort": 587,
  "smtpUseSSL": true,
  "smtpUsername": "youthofnua@163.com",
  "smtpPassword": "这里填授权码",
  "targetEmail": "youthofnua@163.com",
  "maxFileSizeMB": 25
}
```

### 3. 启动服务器

**方式一：双击 `start.bat`**

**方式二：以管理员身份运行 `start.bat`**
（推荐，这样局域网内其他设备才能访问）

**方式三：直接在 PowerShell 中运行**
```powershell
powershell -ExecutionPolicy Bypass -File server.ps1 -Port 8080
```

### 4. 使用

1. 启动后会显示访问地址列表，例如：
   - `http://192.168.1.100:8080/`
   - `http://localhost:8080/`
2. 打开页面，页面上即有二维码
3. 手机扫码即可上传文件
4. 上传成功后，文件会以附件形式发送到 **youthofnua@163.com**

## 常见问题

**Q: 手机扫码打不开页面？**
A: 确保手机和电脑在同一局域网（连接同一个 WiFi），且以管理员身份运行服务器。

**Q: 邮件发送失败？**
A: 检查 `config.json` 中的授权码是否正确，SMTP 端口是否为 587。

**Q: 文件大小有限制吗？**
A: 默认最大 25MB，可在 `config.json` 中调整 `maxFileSizeMB`。

## 文件结构

```
qr-upload/
  server.ps1      # 服务器主程序
  www/
    index.html    # 上传页面
  config.json     # SMTP 配置（自动生成）
  logs/           # 运行日志
  start.bat       # 启动器
```
*** End of File
