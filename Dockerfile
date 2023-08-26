FROM centos:7                       #定义父镜像
MAINTAINER hong                      #定义作者信息
WORKDIR /usr                         #定义默认的工作目录
RUN yum install -y vim            #执行安装vim命令：
 
CMD /bin/bash     
