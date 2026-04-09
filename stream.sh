#!/usr/bin/env bash

#=================================================
#   System Required: CentOS 6/7/8, Ubuntu/Debian, Fedora, Arch, openSUSE
#   Description: ffmpeg 安装 + 视频推流 一体化脚本
#   Version: 3.0
#   Author: 宇宙小哥
#   Github: https://github.com/yuzhouxiaogegit/pushStream
#=================================================

set -euo pipefail

# ================================================
# 公共函数
# ================================================

echoTxtColor(){
    local colorV="1"
    case ${2:-red} in
        green)  colorV="2" ;;
        yellow) colorV="3" ;;
    esac
    echo -e "\033[3${colorV}m ${1} \033[0m"
}

check_root(){
    if [[ $EUID -ne 0 ]]; then
        echoTxtColor "请使用 root 权限运行此脚本 (sudo bash $0)" "red"
        exit 1
    fi
}

require_cmd(){
    if ! command -v "$1" &>/dev/null; then
        echoTxtColor "缺少依赖命令: $1，请先安装或运行菜单选项 [1] 安装 ffmpeg" "red"
        exit 1
    fi
}

detect_arch(){
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)        echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        armv7l)        echo "armhf" ;;
        i686)          echo "i686" ;;
        *)
            echoTxtColor "不支持的架构: ${arch}" "red"
            exit 1
            ;;
    esac
}

pkg_install(){
    if command -v apt-get &>/dev/null; then
        apt-get update -y && apt-get install -y "$@"
    elif command -v dnf &>/dev/null; then
        dnf install -y "$@"
    elif command -v yum &>/dev/null; then
        yum install -y "$@"
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm "$@"
    elif command -v zypper &>/dev/null; then
        zypper install -y "$@"
    else
        echoTxtColor "未找到支持的包管理器，请手动安装: $*" "red"
        exit 1
    fi
}

safe_wget(){
    local url=$1
    local out=$2
    echoTxtColor "下载: ${url}" "yellow"
    if ! wget -q --timeout=30 "${url}" -O "${out}"; then
        echoTxtColor "下载失败: ${url}" "red"
        exit 1
    fi
}

get_latest_version(){
    local url=$1
    local name=$2
    local tmpfile
    tmpfile=$(mktemp)
    wget -q --timeout=10 "${url}" -O "${tmpfile}" 2>/dev/null || true
    local version=""
    if [[ $url =~ github\.com ]]; then
        version=$(grep -Eo 'tag/[vV]?[0-9.]+[0-9]' "${tmpfile}" \
            | grep -Eo '[vV]?[0-9.]+[0-9]' | head -n1)
    else
        version=$(grep -Eo "${name}[._-]?[vV]?[0-9.]+[0-9]" "${tmpfile}" \
            | grep -Eo '[vV]?[0-9.]+[0-9]' | tail -n1)
    fi
    rm -f "${tmpfile}"
    echo "${version}"
}

get_github_release(){
    wget -qO- --timeout=10 "https://api.github.com/repos/${1}/releases/latest" \
        | grep '"tag_name"' | head -n1 | awk -F'"' '{print $4}'
}

# ================================================
# ffmpeg 安装模块
# ================================================

FFMPEG_INSTALL_PREFIX="/usr/local/ffmpeg"
YASM_DEFAULT_VERSION="1.3.0"
FFMPEG_DEFAULT_VERSION="6.1"

check_existing_ffmpeg(){
    if command -v ffmpeg &>/dev/null; then
        local cur_ver
        cur_ver=$(ffmpeg -version 2>&1 | head -n1)
        echoTxtColor "检测到已安装 ffmpeg: ${cur_ver}" "yellow"
        read -rp "是否重新安装？(y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echoTxtColor "已取消安装" "yellow"
            return 1
        fi
    fi
    return 0
}

install_yasm(){
    local version=$1
    echoTxtColor "编译安装 yasm-${version}..." "yellow"
    safe_wget "http://www.tortall.net/projects/yasm/releases/yasm-${version}.tar.gz" \
        "yasm-${version}.tar.gz"
    tar -zxf "yasm-${version}.tar.gz"
    cd "yasm-${version}"
    ./configure --prefix=/usr/local
    make -j"$(nproc)" && make install
    cd ..
    echoTxtColor "yasm 安装完成" "green"
}

install_ffmpeg_src(){
    local version=$1
    echoTxtColor "编译安装 ffmpeg-${version}..." "yellow"
    safe_wget "http://www.ffmpeg.org/releases/ffmpeg-${version}.tar.gz" \
        "ffmpeg-${version}.tar.gz"
    tar -zxf "ffmpeg-${version}.tar.gz"
    cd "ffmpeg-${version}"
    ./configure --prefix="${FFMPEG_INSTALL_PREFIX}" --enable-gpl --enable-nonfree \
        || ./configure --prefix="${FFMPEG_INSTALL_PREFIX}" --enable-gpl --enable-nonfree --disable-x86asm
    make -j"$(nproc)" && make install
    cd ..
    echoTxtColor "ffmpeg 编译完成" "green"
}

setup_ffmpeg_env(){
    local bin_dir="${FFMPEG_INSTALL_PREFIX}/bin"
    if ! grep -q "${bin_dir}" /etc/profile; then
        echo "export PATH=\$PATH:${bin_dir}" >> /etc/profile
    fi
    ln -sf "${bin_dir}/ffmpeg"  /usr/local/bin/ffmpeg
    ln -sf "${bin_dir}/ffprobe" /usr/local/bin/ffprobe
    echoTxtColor "环境变量配置完成，软链接已创建" "green"
}

cmd_install_ffmpeg(){
    check_root
    check_existing_ffmpeg || return 0

    detect_arch
    echoTxtColor "安装编译依赖..." "yellow"
    pkg_install wget tar gcc make yasm nasm

    local WORK_DIR
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf "${WORK_DIR}"' RETURN
    cd "${WORK_DIR}"

    echoTxtColor "获取 yasm 最新版本..." "yellow"
    local yasmVersion
    yasmVersion=$(get_latest_version 'http://www.tortall.net/projects/yasm/releases/' 'yasm')
    yasmVersion="${yasmVersion:-${YASM_DEFAULT_VERSION}}"
    install_yasm "${yasmVersion}"

    echoTxtColor "获取 ffmpeg 最新版本..." "yellow"
    local ffmpegVersion
    ffmpegVersion=$(get_latest_version 'http://www.ffmpeg.org/releases/' 'ffmpeg')
    ffmpegVersion="${ffmpegVersion:-${FFMPEG_DEFAULT_VERSION}}"
    install_ffmpeg_src "${ffmpegVersion}"

    setup_ffmpeg_env
    echoTxtColor "ffmpeg ${ffmpegVersion} 安装完成！执行 'ffmpeg -version' 验证" "green"
}

# ================================================
# 推流模块
# ================================================

M3U8_REPO="llychao/m3u8-downloader"

get_m3u8_bin_name(){
    local arch
    arch=$(detect_arch)
    case $arch in
        x86_64)  echo "m3u8-linux-amd64" ;;
        aarch64) echo "m3u8-linux-arm64" ;;
        armhf)   echo "m3u8-linux-arm"   ;;
        *)
            echoTxtColor "m3u8-downloader 不支持当前架构: ${arch}" "red"
            exit 1
            ;;
    esac
}

ensure_m3u8_tool(){
    local bin_name=$1
    [[ -f "./${bin_name}" ]] && return
    local version
    version=$(get_github_release "${M3U8_REPO}")
    if [[ -z "$version" ]]; then
        echoTxtColor "无法获取 m3u8-downloader 版本，请检查网络" "red"
        exit 1
    fi
    safe_wget \
        "https://github.com/${M3U8_REPO}/releases/download/${version}/${bin_name}" \
        "./${bin_name}"
    chmod 755 "./${bin_name}"
}

download_video(){
    local url=$1
    local output=$2
    if [[ "$url" =~ \.m3u8 ]]; then
        local bin_name
        bin_name=$(get_m3u8_bin_name)
        ensure_m3u8_tool "${bin_name}"
        echoTxtColor "正在下载 m3u8 视频..." "yellow"
        "./${bin_name}" -u="${url}" -o="${output}"
        [[ ! -f "${output}.mp4" && -f "${output}" ]] && mv "${output}" "${output}.mp4"
    else
        echoTxtColor "正在下载 mp4 视频..." "yellow"
        safe_wget "${url}" "${output}.mp4"
    fi
}

do_push(){
    local video_file=$1
    local rtmp=$2
    echoTxtColor "开始推流到 ${rtmp} ..." "yellow"
    ffmpeg -re -i "${video_file}" \
        -c:v copy \
        -c:a aac -b:a 192k \
        -strict -2 \
        -f flv "${rtmp}"
}

cmd_push_video(){
    require_cmd ffmpeg
    require_cmd wget

    read -rp "请输入视频地址（http mp4直链 / m3u8地址 / 本地文件路径）: " inputUrl
    [[ -z "$inputUrl" ]] && { echoTxtColor "视频地址不能为空" "red"; return 1; }

    local IS_LOCAL=false
    if [[ ! "$inputUrl" =~ ^http ]]; then
        [[ -f "$inputUrl" ]] || { echoTxtColor "本地文件不存在: ${inputUrl}" "red"; return 1; }
        IS_LOCAL=true
    fi

    local videoFile videoName
    if [[ "$IS_LOCAL" = true ]]; then
        videoFile="$inputUrl"
    else
        read -rp "请输入下载后的文件名（不含扩展名，默认 tempVideo）: " videoName
        videoName="${videoName:-tempVideo}"
        videoFile="${videoName}.mp4"
    fi

    read -rp "请输入推流地址（rtmp://...）: " rtmp
    [[ "$rtmp" =~ ^rtmp:// ]] || { echoTxtColor "请输入有效的 RTMP 地址（rtmp:// 开头）" "red"; return 1; }

    if [[ "$IS_LOCAL" = false ]]; then
        download_video "${inputUrl}" "${videoName}"
    fi

    [[ -f "${videoFile}" ]] || { echoTxtColor "视频文件不存在: ${videoFile}" "red"; return 1; }

    if do_push "${videoFile}" "${rtmp}"; then
        echoTxtColor "推流完成！" "green"
        if [[ "$IS_LOCAL" = false ]]; then
            rm -f "${videoFile}"
            echoTxtColor "已清理临时文件: ${videoFile}" "yellow"
        fi
    else
        echoTxtColor "推流失败，文件保留在: ${videoFile}" "red"
        return 1
    fi
}

# ================================================
# 主菜单
# ================================================

show_menu(){
    echo ""
    echo "================================================="
    echoTxtColor "       视频推流工具 v3.0" "green"
    echo "================================================="
    echo "  1. 安装 ffmpeg（需要 root 权限）"
    echo "  2. 开始推流"
    echo "  0. 退出"
    echo "================================================="
    read -rp "请选择操作 [0-2]: " choice
    case $choice in
        1) cmd_install_ffmpeg ;;
        2) cmd_push_video ;;
        0) echoTxtColor "已退出" "yellow"; exit 0 ;;
        *) echoTxtColor "无效选项，请输入 0、1 或 2" "red" ;;
    esac
}

# 支持直接传参跳过菜单: bash stream.sh install | push
case "${1:-}" in
    install) cmd_install_ffmpeg ;;
    push)    cmd_push_video ;;
    *)       while true; do show_menu; done ;;
esac
