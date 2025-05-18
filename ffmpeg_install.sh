#!/usr/bin/env bash

#=================================================
#	System Required: CentOS 6/7/8
#	Description: ffmpeg 安装脚本
#	Version: 1.1
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

# 获取最新软件版本号码,非gitbub版本号也能获取,例如:ffmpeg等
# $1 = 软件releases地址
# $2 = 软件名称
# 函数调用示例 getNewVersionNum 'https://github.com/fatedier/frp/releases/' 'frp'
getNewVersionNum(){
	wget --timeout=10 $1 -O temp_$2.txt && echo "$(grep -Eo $2.[0-9.]+ temp_$2.txt | grep -Eo [0-9.]+[0-9] | tail -n 1)" && rm -rf temp_$2.txt
}

cd
# 安装编译工具 yasm
yasmVersion=$(getNewVersionNum 'http://www.tortall.net/projects/yasm/releases/' 'yasm') # 获取yasm最新版本号
wget http://www.tortall.net/projects/yasm/releases/yasm-${yasmVersion}.tar.gz
tar -zxvf yasm-${yasmVersion}.tar.gz
cd yasm-${yasmVyasmVersion}
./configure
make && make install

# 下载并且安装 ffmpeg
cd
ffmpegVersion=$(getNewVersionNum 'http://www.ffmpeg.org/releases/' 'ffmpeg') # 获取yasm最新版本号
wget http://www.ffmpeg.org/releases/ffmpeg-${ffmpegVersion}.tar.gz
tar -zxvf ffmpeg-${ffmpegVersion}.tar.gz
cd ffmpeg-${ffmpegVersion}
./configure --prefix=/usr/local/ffmpeg
make && make install

# 配置变量
echo 'export PATH=$PATH:/usr/local/ffmpeg/bin'>>/etc/profile
source /etc/profile

cd
rm -rf yasm-1.3.0.tar.gz
rm -rf ffmpeg-${ffmpegVersion}.tar.gz
echoTxtColor "ffmpeg 安装完成" "green"
exit
