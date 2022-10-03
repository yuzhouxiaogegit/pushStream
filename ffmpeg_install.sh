#!/usr/bin/env bash

#=================================================
#	System Required: CentOS 6/7/8
#	Description: ffmpeg 安装脚本
#	Version: 1.0
#	Author: 宇宙小哥
#	Blog: https://github.com/yuzhouxiaogegit/pushStream
#=================================================

# 打印文字颜色方法
echoTxtColor(){
	
	colorV="1"
	
	if [[ $2 = 'red' ]];
	then
		colorV="1"
	elif [[ $2 = 'green' ]];
	then
		colorV="2"
	elif [[ $2 = 'yellow' ]];
	then
		colorV="3"
	fi
	
	echo -e "\033[3${colorV}m ${1} \033[0m"
}
# 调用示例
# echoTxtColor "您的文字颜色打印成功" "green"

read -p "请输入你要下载ffmpeg的版本号，(直接回车下载5.1版本):" ffmpegVersion

if [[ $ffmpegVersion = "" ]]; then
	ffmpegVersion="5.1"
fi

# 安装编译工具 yasm
wget http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz
tar -zxvf yasm-1.3.0.tar.gz
cd yasm-1.3.0
./configure
make && make install

# 下载并且安装 ffmpeg
cd
wget http://www.ffmpeg.org/releases/ffmpeg-${ffmpegVersion}.tar.gz
tar -zxvf ffmpeg-${ffmpegVersion}.tar.gz
cd ffmpeg-${ffmpegVersion}
./configure --prefix=/usr/local/ffmpeg
make && make install

# 配置变量
echo 'export PATH=$PATH:/usr/local/ffmpeg/bin'>>/etc/profile

rm -rf yasm-1.3*
rm -rf ffmpeg-${ffmpegVersion}*

echoTxtColor "ffmpeg 安装完成" "green"
exit

