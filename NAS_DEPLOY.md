========================================
绿联云 NAS 部署指南
========================================

方法一：Docker（推荐，最简单）
----------------------------------------
1. 打开绿联云 NAS 的「应用中心」
2. 安装「Docker」应用
3. 把 qr-upload 整个文件夹复制到 NAS 的共享文件夹中
4. 打开 Docker，进入「镜像」→「本地镜像」→「添加」
5. 选择 qr-upload 文件夹中的 Dockerfile 进行构建
6. 构建完成后，创建容器：
   - 端口映射：本地 8080 → 容器 8080
   - 选择「使用高权限模式」
   - 勾选「开机自动启动」
7. 启动容器

之后浏览器打开 http://你的NASIP:8080/ 即可使用。

方法二：Python 直接运行（需先装 Python）
----------------------------------------
1. 在 NAS 后台开启 SSH（设置 → 终端）
2. 用 PuTTY 或终端 SSH 连上你的 NAS
3. 执行：python3 --version
4. 如果提示没有 Python，先安装：
   sudo apt update && sudo apt install python3 -y
5. 将 qr-upload 文件夹复制到 NAS
6. 进入文件夹后运行：
   python3 server.py &

让外网访问（Cloudflare Tunnel 免费方案）
----------------------------------------
在 NAS 上运行 server.py 后，再运行：
docker run -d --name cloudflared cloudflare/cloudflared tunnel --url http://localhost:8080

会得到一个 https://xxxx.trycloudflare.com 的地址
任何人用这个地址就能上传文件了！
