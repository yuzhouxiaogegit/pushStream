#!/bin/bash

#=================================================
#	System Required: CentOS 6/7/8
#	Description: 视频推流脚本
#	Version: 1.0
#	Author: 宇宙小哥
#	github: https://github.com/yuzhouxiaogegit/pushStream
# 	ffmpeg	下载地址：https://github.com/BtbN/FFmpeg-Builds/releases ， 需要手动安装
#=================================================

#多少位的系统
#bitNum=$(getconf LONG_BIT)

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


# 获取github 项目中的最新版本号
getVersion(){
	# 获取github项目中最新版本号
	echo $(wget -qO- -t1 -T2 "https://api.github.com/${1}/m3u8-downloader/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
}
# 调用示例
# 传入项目名称  "repos/llychao"
# getVersion "repos/llychao"



# 下载视频视频地址
read -p "请输入您要下载的视频地址（支持 mp4地址\m3u8地址\本地视频地址:例如/opt/video.mp4）:" inputUrl

if 
	[[ $inputUrl =~ "http" || $inputUrl =~ ".mp4" ]];
then
	echo ''
else
	echoTxtColor "请输入有效的视频地址！" "red"
	exit
fi

if 
	[[ $inputUrl =~ "http" ]];
then
	#重命名视频名称
	read -p "请输入您下载后的视频名称（不支持中文名称）,默认值 tempVideo.mp4:" videoName

	if 
		[[ $videoName = "" ]];
	then
		videoName=tempVideo
	fi
fi

# 定义推流地址
read -p "输入你的推流地址和推流码(rtmp协议):" rtmp

if 
	[[ $rtmp =~ "rtmp" ]];
then
	echo ''
else
	echoTxtColor "请输入有效的推流地址！" "red"
	exit
fi

if [[ $inputUrl =~ ".m3u8" ]];
then
	
	if [[ $(find ./ -name m3u8-linux-amd64) = "" ]];
	then
	
		# 获取github项目中最新版本号
		version=$(getVersion "repos/llychao")
		
		# 下载最新版本的 m3u8-linux-amd64
		wget https://github.com/llychao/m3u8-downloader/releases/download/${version}/m3u8-linux-amd64 && chmod 755 ./m3u8-linux-amd64
	fi

	./m3u8-linux-amd64 -u=${inputUrl} -o=${videoName}
	
elif [[ $inputUrl =~ "http" && $inputUrl =~ ".mp4" ]];
then
	wget -c ${inputUrl} -O ${videoName}.mp4
fi

if 
	[[ $videoName = "" ]];
then
	videoName=${inputUrl}
else
	videoName="${videoName}.mp4"
fi




ffmpeg -re -i ${videoName} -c:v copy -c:a aac -b:a 192k -strict -2 -f flv ${rtmp}
rm -rf ${videoName}

echoTxtColor "您的视频已推送已结束！" "green"

exit
