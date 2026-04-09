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

## 运行

一行命令直接运行，无需克隆仓库：

```bash
# curl
bash <(curl -fsSL https://raw.githubusercontent.com/yuzhouxiaogegit/pushStream/main/stream.sh)

# wget
bash <(wget -qO- https://raw.githubusercontent.com/yuzhouxiaogegit/pushStream/main/stream.sh)
```

或下载到本地运行：

```bash
wget https://raw.githubusercontent.com/yuzhouxiaogegit/pushStream/main/stream.sh
bash stream.sh
```

---

## 使用教程

启动后进入交互菜单：

```
=================================================
        视频推流工具 v2.0
=================================================
  1. 安装 ffmpeg（需要 root 权限）
  2. 卸载 ffmpeg（需要 root 权限）
  3. 开始推流
  0. 退出
=================================================
```

### 选项 1：安装 ffmpeg

首次使用选择 `1`，脚本会自动完成：

1. 检测系统包管理器，安装编译依赖（gcc、make、yasm、nasm 等）
2. 从官网获取最新版本并编译安装到 `/usr/local/ffmpeg`
3. 创建软链接到 `/usr/local/bin`，写入 `/etc/profile` 环境变量

安装完成后验证：

```bash
ffmpeg -version
```

> 如已安装 ffmpeg，脚本会询问是否重新安装，可选择跳过。
> ffmpeg 编译耗时约 10~30 分钟，视机器性能而定，请耐心等待。

### 选项 2：卸载 ffmpeg

选择 `2`，脚本会清理以下内容：

- `/usr/local/ffmpeg` 安装目录
- `/usr/local/bin/ffmpeg` 和 `ffprobe` 软链接
- `/etc/profile` 中写入的 PATH 配置

### 选项 3：推流

选择 `3`，按提示依次输入：

**1. 视频地址**，支持三种格式：

| 格式                | 示例                             |
| ------------------- | -------------------------------- |
| http/https mp4 直链 | `https://example.com/video.mp4`  |
| m3u8 流媒体地址     | `https://example.com/index.m3u8` |
| 本地文件路径        | `/opt/video.mp4`                 |

**2. 保存文件名**（仅远程地址需要，默认 `tempVideo`）

**3. RTMP 推流地址**：

```
rtmp://live.example.com/live/your_stream_key
```

推流开始后终端会显示 ffmpeg 实时编码信息，按 `q` 可中断。推流结束后远程临时文件自动清理，本地文件不会被删除，推流失败时文件保留方便重试。

---

## 注意事项

- 安装 / 卸载需要 root 权限，推流不需要
- m3u8 下载依赖 [m3u8-downloader](https://github.com/llychao/m3u8-downloader)，脚本按系统架构自动下载对应二进制
- 安装完成后若 `ffmpeg` 命令找不到，执行 `source /etc/profile` 或重新登录即可（通常软链接已自动创建，无需此步骤）
