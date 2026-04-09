#!/usr/bin/env bash

#=================================================
#   System Required: CentOS 6/7/8, Ubuntu/Debian, Fedora, Arch, openSUSE
#   Description: ffmpeg 安装 + 视频推流 一体化脚本
#   Version: 2.0
#   Author: 宇宙小哥
#   Github: https://github.com/yuzhouxiaogegit/pushStream
#=================================================

set -euo pipefail

# ================================================
# 常量
# ================================================

FFMPEG_INSTALL_PREFIX="/usr/local/ffmpeg"
YASM_DEFAULT_VERSION="1.3.0"
FFMPEG_DEFAULT_VERSION="6.1"
M3U8_REPO="llychao/m3u8-downloader"

# ================================================
# 工具函数
# ================================================

# 彩色输出: log_info / log_warn / log_error
log_info()  { echo -e "\033[32m [INFO]  ${1} \033[0m"; }
log_warn()  { echo -e "\033[33m [WARN]  ${1} \033[0m"; }
log_error() { echo -e "\033[31m [ERROR] ${1} \033[0m"; }

check_root(){
    [[ $EUID -eq 0 ]] || { log_error "请使用 root 权限运行 (sudo bash $0)"; exit 1; }
}

require_cmd(){
    command -v "$1" &>/dev/null || {
        log_error "缺少命令: $1，请先通过菜单选项 [1] 安装 ffmpeg"
        exit 1
    }
}

detect_arch(){
    case $(uname -m) in
        x86_64)        echo "x86_64"  ;;
        aarch64|arm64) echo "aarch64" ;;
        armv7l)        echo "armhf"   ;;
        i686)          echo "i686"    ;;
        *) log_error "不支持的架构: $(uname -m)"; exit 1 ;;
    esac
}

pkg_install(){
    if   command -v apt-get &>/dev/null; then apt-get update -y && apt-get install -y "$@"
    elif command -v dnf     &>/dev/null; then dnf install -y "$@"
    elif command -v yum     &>/dev/null; then yum install -y "$@"
    elif command -v pacman  &>/dev/null; then pacman -Sy --noconfirm "$@"
    elif command -v zypper  &>/dev/null; then zypper install -y "$@"
    else log_error "未找到支持的包管理器，请手动安装: $*"; exit 1
    fi
}

# 带进度条下载，失败则退出
safe_wget(){
    local url=$1 out=$2
    log_warn "下载: ${url}"
    wget --timeout=60 --progress=bar:force -O "${out}" "${url}" || {
        log_error "下载失败: ${url}"
        exit 1
    }
}

# 从 releases 页面抓最新版本号
get_latest_version(){
    local url=$1 name=$2 tmpfile version
    tmpfile=$(mktemp)
    wget -q --timeout=10 -O "${tmpfile}" "${url}" 2>/dev/null || true
    if [[ $url =~ github\.com ]]; then
        version=$(grep -Eo 'tag/[vV]?[0-9.]+[0-9]' "${tmpfile}" | grep -Eo '[vV]?[0-9.]+[0-9]' | head -n1)
    else
        version=$(grep -Eo "${name}[._-]?[vV]?[0-9.]+[0-9]" "${tmpfile}" | grep -Eo '[vV]?[0-9.]+[0-9]' | tail -n1)
    fi
    rm -f "${tmpfile}"
    echo "${version}"
}

# 从 GitHub API 获取最新 release tag
get_github_release(){
    wget -qO- --timeout=10 "https://api.github.com/repos/${1}/releases/latest" \
        | grep '"tag_name"' | head -n1 | awk -F'"' '{print $4}'
}

# ================================================
# ffmpeg 安装模块
# ================================================

check_existing_ffmpeg(){
    if command -v ffmpeg &>/dev/null; then
        log_warn "检测到已安装: $(ffmpeg -version 2>&1 | head -n1)"
        read -rp " 是否重新安装？(y/N): " confirm
        [[ $confirm =~ ^[Yy]$ ]] || { log_warn "已取消"; return 1; }
    fi
    return 0
}

install_yasm(){
    local version=$1
    log_warn "编译安装 yasm-${version}..."
    safe_wget "http://www.tortall.net/projects/yasm/releases/yasm-${version}.tar.gz" \
        "yasm-${version}.tar.gz"
    tar -zxf "yasm-${version}.tar.gz"
    pushd "yasm-${version}" > /dev/null
    ./configure --prefix=/usr/local
    make -j"$(nproc)" && make install
    popd > /dev/null
    log_info "yasm 安装完成"
}

install_ffmpeg_src(){
    local version=$1
    log_warn "下载 ffmpeg-${version} 源码..."
    safe_wget "http://www.ffmpeg.org/releases/ffmpeg-${version}.tar.gz" \
        "ffmpeg-${version}.tar.gz"
    log_warn "解压中..."
    tar -zxf "ffmpeg-${version}.tar.gz"
    pushd "ffmpeg-${version}" > /dev/null
    log_warn "配置编译选项..."
    # 优先带汇编优化，nasm 版本不满足时自动降级
    if ! ./configure --prefix="${FFMPEG_INSTALL_PREFIX}" --enable-gpl --enable-nonfree 2>/dev/null; then
        log_warn "nasm 版本不满足，降级使用 --disable-x86asm"
        ./configure --prefix="${FFMPEG_INSTALL_PREFIX}" --enable-gpl --enable-nonfree --disable-x86asm
    fi
    log_warn "开始编译（$(nproc) 核心），耗时约 10~30 分钟，请耐心等待..."
    make -j"$(nproc)"
    log_warn "安装中..."
    make install
    popd > /dev/null
    log_info "ffmpeg 编译完成"
}

setup_ffmpeg_env(){
    local bin_dir="${FFMPEG_INSTALL_PREFIX}/bin"
    grep -q "${bin_dir}" /etc/profile \
        || echo "export PATH=\$PATH:${bin_dir}" >> /etc/profile
    ln -sf "${bin_dir}/ffmpeg"  /usr/local/bin/ffmpeg
    ln -sf "${bin_dir}/ffprobe" /usr/local/bin/ffprobe
    log_info "软链接已创建，环境变量已写入 /etc/profile"
}

cmd_install_ffmpeg(){
    check_root
    check_existing_ffmpeg || return 0
    detect_arch > /dev/null  # 架构校验，不支持则提前退出

    log_warn "安装编译依赖..."
    pkg_install wget tar gcc make yasm nasm

    local WORK_DIR
    WORK_DIR=$(mktemp -d)
    # 函数退出时自动清理临时目录并恢复目录
    trap 'popd > /dev/null 2>&1; rm -rf "${WORK_DIR}"' RETURN
    pushd "${WORK_DIR}" > /dev/null

    log_warn "获取 yasm 最新版本..."
    local yasmVersion
    yasmVersion=$(get_latest_version 'http://www.tortall.net/projects/yasm/releases/' 'yasm')
    install_yasm "${yasmVersion:-${YASM_DEFAULT_VERSION}}"

    log_warn "获取 ffmpeg 最新版本..."
    local ffmpegVersion
    ffmpegVersion=$(get_latest_version 'http://www.ffmpeg.org/releases/' 'ffmpeg')
    ffmpegVersion="${ffmpegVersion:-${FFMPEG_DEFAULT_VERSION}}"
    install_ffmpeg_src "${ffmpegVersion}"

    setup_ffmpeg_env
    log_info "ffmpeg ${ffmpegVersion} 安装完成！运行 'ffmpeg -version' 验证"
}

# ================================================
# ffmpeg 卸载模块
# ================================================

cmd_uninstall_ffmpeg(){
    check_root
    local removed=false

    for bin in ffmpeg ffprobe; do
        if [[ -L "/usr/local/bin/${bin}" ]]; then
            rm -f "/usr/local/bin/${bin}"
            log_warn "已移除软链接: /usr/local/bin/${bin}"
            removed=true
        fi
    done

    if [[ -d "${FFMPEG_INSTALL_PREFIX}" ]]; then
        rm -rf "${FFMPEG_INSTALL_PREFIX}"
        log_warn "已移除安装目录: ${FFMPEG_INSTALL_PREFIX}"
        removed=true
    fi

    local bin_dir="${FFMPEG_INSTALL_PREFIX}/bin"
    if grep -q "${bin_dir}" /etc/profile 2>/dev/null; then
        sed -i "\|${bin_dir}|d" /etc/profile
        log_warn "已清理 /etc/profile 中的 PATH 配置"
        removed=true
    fi

    if [[ "$removed" = true ]]; then
        log_info "ffmpeg 卸载完成"
    else
        log_warn "未检测到已安装的 ffmpeg，无需卸载"
    fi
}

# ================================================
# 推流模块
# ================================================

get_m3u8_bin_name(){
    case $(detect_arch) in
        x86_64)  echo "m3u8-linux-amd64" ;;
        aarch64) echo "m3u8-linux-arm64" ;;
        armhf)   echo "m3u8-linux-arm"   ;;
        *) log_error "m3u8-downloader 不支持当前架构"; exit 1 ;;
    esac
}

ensure_m3u8_tool(){
    local bin_name=$1
    [[ -f "./${bin_name}" ]] && return 0

    local version
    version=$(get_github_release "${M3U8_REPO}")
    [[ -n "$version" ]] || { log_error "无法获取 m3u8-downloader 版本，请检查网络"; exit 1; }

    safe_wget \
        "https://github.com/${M3U8_REPO}/releases/download/${version}/${bin_name}" \
        "./${bin_name}"
    chmod 755 "./${bin_name}"
}

download_video(){
    local url=$1 output=$2
    if [[ "$url" =~ \.m3u8 ]]; then
        local bin_name
        bin_name=$(get_m3u8_bin_name)
        ensure_m3u8_tool "${bin_name}"
        log_warn "正在下载 m3u8 视频..."
        "./${bin_name}" -u="${url}" -o="${output}"
        # 部分版本输出文件不带 .mp4，统一修正
        [[ ! -f "${output}.mp4" && -f "${output}" ]] && mv "${output}" "${output}.mp4"
    else
        log_warn "正在下载 mp4 视频..."
        safe_wget "${url}" "${output}.mp4"
    fi
}

do_push(){
    local video_file=$1 rtmp=$2
    log_warn "开始推流到 ${rtmp}，按 q 中断..."
    ffmpeg -re -i "${video_file}" \
        -c:v copy \
        -c:a aac -b:a 192k \
        -strict -2 \
        -f flv "${rtmp}"
}

cmd_push_video(){
    require_cmd ffmpeg
    require_cmd wget

    # 输入视频地址
    read -rp " 请输入视频地址（mp4直链 / m3u8地址 / 本地路径）: " inputUrl
    [[ -n "$inputUrl" ]] || { log_error "视频地址不能为空"; return 1; }

    # 判断本地 or 远程
    local IS_LOCAL=false
    if [[ ! "$inputUrl" =~ ^https?:// ]]; then
        [[ -f "$inputUrl" ]] || { log_error "本地文件不存在: ${inputUrl}"; return 1; }
        IS_LOCAL=true
    fi

    # 确定本地文件路径
    local videoFile videoName
    if [[ "$IS_LOCAL" = true ]]; then
        videoFile="$inputUrl"
    else
        read -rp " 请输入保存的文件名（不含扩展名，默认 tempVideo）: " videoName
        videoName="${videoName:-tempVideo}"
        videoFile="${videoName}.mp4"
    fi

    # 输入推流地址
    read -rp " 请输入 RTMP 推流地址（rtmp://...）: " rtmp
    [[ "$rtmp" =~ ^rtmp:// ]] || { log_error "推流地址必须以 rtmp:// 开头"; return 1; }

    # 下载远程视频
    [[ "$IS_LOCAL" = false ]] && download_video "${inputUrl}" "${videoName}"

    [[ -f "${videoFile}" ]] || { log_error "视频文件不存在: ${videoFile}"; return 1; }

    # 推流
    if do_push "${videoFile}" "${rtmp}"; then
        log_info "推流完成"
        if [[ "$IS_LOCAL" = false ]]; then
            rm -f "${videoFile}"
            log_warn "已清理临时文件: ${videoFile}"
        fi
    else
        log_error "推流失败，文件保留在: ${videoFile}"
        return 1
    fi
}

# ================================================
# 主菜单
# ================================================

show_menu(){
    echo ""
    echo "================================================="
    echo -e "\033[32m        视频推流工具 v2.0 \033[0m"
    echo "================================================="
    echo "  1. 安装 ffmpeg（需要 root 权限）"
    echo "  2. 卸载 ffmpeg（需要 root 权限）"
    echo "  3. 开始推流"
    echo "  0. 退出"
    echo "================================================="
    read -rp " 请选择操作 [0-3]: " choice
    echo ""
    case $choice in
        1) cmd_install_ffmpeg   ;;
        2) cmd_uninstall_ffmpeg ;;
        3) cmd_push_video       ;;
        0) log_info "已退出"; exit 0 ;;
        *) log_error "无效选项: ${choice}" ;;
    esac
}

while true; do show_menu; done
