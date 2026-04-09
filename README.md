# 视频推流脚本

基于 ffmpeg 的一体化视频推流工具，支持 mp4 直链、m3u8 流媒体、本地文件推送到 RTMP 直播地址。

## 支持系统

| 发行版          | 包管理器 |
| --------------- | -------- |
| Ubuntu / Debian | apt-get  |
| CentOS 6/7/8    | yum      |
| Fedora          | dnf      |
| Arch Linux      | pacman   |
| openSUSE        | zypper   |

支持架构：`x86_64` / `aarch64` / `armhf` / `i686`

---

## 安装 & 运行

一行命令直接运行，无需克隆仓库：

```bash
# 使用 curl
bash <(curl -fsSL https://raw.githubusercontent.com/yuzhouxiaogegit/pushStream/main/stream.sh)
```

```bash
# 使用 wget
bash <(wget -qO- https://raw.githubusercontent.com/yuzhouxiaogegit/pushStream/main/stream.sh)
```

或者下载到本地后运行：

```bash
wget https://raw.githubusercontent.com/yuzhouxiaogegit/pushStream/main/stream.sh
chmod +x stream.sh
bash stream.sh
```

---

## 使用教程

### 启动脚本

```bash
bash stream.sh
```

启动后进入交互菜单：

```
=================================================
       视频推流工具 v3.0
=================================================
  1. 安装 ffmpeg（需要 root 权限）
  2. 开始推流
  0. 退出
=================================================
```

---

### 第一步：安装 ffmpeg

首次使用需要先安装 ffmpeg，选择菜单 `1` 或直接运行：

```bash
sudo bash stream.sh install
```

脚本会自动完成以下步骤：

1. 检测系统包管理器，安装编译依赖（gcc、make、yasm 等）
2. 从官网获取 yasm 和 ffmpeg 最新版本并编译安装
3. 配置环境变量，创建软链接到 `/usr/local/bin`

安装完成后验证：

```bash
ffmpeg -version
```

> 如果已安装 ffmpeg，脚本会询问是否重新安装，可以选择跳过。

---

### 第二步：推流

选择菜单 `2` 或直接运行：

```bash
bash stream.sh push
```

按提示依次输入以下信息：

**1. 视频地址**，支持三种格式：

| 格式            | 示例                             |
| --------------- | -------------------------------- |
| http mp4 直链   | `https://example.com/video.mp4`  |
| m3u8 流媒体地址 | `https://example.com/index.m3u8` |
| 本地文件路径    | `/opt/video.mp4`                 |

**2. 下载文件名**（仅远程地址需要填写，默认 `tempVideo`）

**3. RTMP 推流地址**，格式为 `rtmp://` 开头：

```
rtmp://live.example.com/live/your_stream_key
```

推流开始后终端会显示 ffmpeg 实时编码信息，按 `q` 可中断推流。

---

### 推流完成后

- 远程下载的临时视频文件会自动清理
- 本地文件不会被删除
- 推流失败时临时文件会保留，方便重试

---

## 注意事项

- 安装 ffmpeg 需要 root 权限，推流不需要
- m3u8 下载依赖 [m3u8-downloader](https://github.com/llychao/m3u8-downloader)，脚本会根据系统架构自动下载对应二进制（amd64 / arm64 / arm）
- ffmpeg 编译耗时较长（视机器性能约 10~30 分钟），请耐心等待
- 安装完成后若 `ffmpeg` 命令找不到，执行 `source /etc/profile` 或重新登录即可（软链接已自动创建，通常不需要此步骤）
