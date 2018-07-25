#!/bin/bash


#需要上传jdk， tomcat软件包，自启动脚本; mysql_back_up文件夹，redis安装包
#首先自己设置用户名变量A_NAME

A_NAME=
#wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo

#1
yum update
yum -y install autoconf automake binutils bison flex gcc gcc-c++ gettext libtool make patch pkgconfig rpm-build  yum-utils epel-release
yum-plugin-fastestmirror yum-plugin-downloadonly openssl-devel nc curl wget  man nss vim system-config-network-tui bind-utils lokkit  pciutils redhat-lsb-core libX11 libXp telnet




#2. for mysql
wget https://mirrors.tuna.tsinghua.edu.cn/mysql/yum/mysql57-community-el6/mysql57-community-release-el6-7.noarch.rpm
rpm -ivh mysql57-community-release-el6-7.noarch.rpm
sed -ie '27 s/0/1/; 34 s/1/0/' /etc/yum.repos.d/mysql-community.repo   #参数i必须在参数e前面,e表示可以有多个命令
yum -y install mysql-community-server mysql-community-devel mysql-community-client

#centos7中貌似可用mariadb代替mysql客户端：yum install -y mariadb.x86_64 mariadb-libs.x86_64

#sed -i -e '2 i character-set-server=uft8' -e '2 i binlog-format=row' /etc/my.cnf
sed -ir '/\[mysqld\]/a character-set-server=utf8 \nbinlog-format=row' /etc/my.cnf

service mysqld start





#3. create user


#A_NAME=$(cat /etc/passwd | grep 500 | cut -d: -f 1) #有的系统是500，所以取不到。
#[ -z "A_NAME" ] && /usr/sbin/useradd axinfu
#A_NAME=$(cat /etc/passwd | grep 500 | cut -d: -f 1)


su - $A_NAME -c "mkdir axinfu && cd axinfu && mkdir mgrfilepath cert accountfile config"





#4. for JDK
JdkPath="/usr/lib/jvm"

if [ ! -d "$JdkPath" ]; then
   mkdir -p $JdkPath  #attention here
fi

tar xzvf jdk.tar.gz -C /usr/lib/jvm

update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk1.7.0_80/bin/java" 1
update-alternatives --install "/usr/bin/javac" "javac" "/usr/lib/jvm/jdk1.7.0_80/bin/javac" 1
update-alternatives --install "/usr/bin/javaws" "javaws" "/usr/lib/jvm/jdk1.7.0_80/bin/javaws" 1

#set env for jdk
JAVA_HOME=/usr/lib/jvm/jdk1.7.0_80

(
cat << EOF
export JAVA_HOME=/usr/lib/jvm/jdk1.7.0_80
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
EOF
)>>/etc/profile

#another way, this is better
#cat >> /etc/profile <<EOF
#LINE 1
#LINE 2
#EOF
source /etc/profile






#5. for tomcat

#wget https://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-7/v7.0.79/bin/apache-tomcat-7.0.79.tar.gz
tar xzvf apache-tomcat-7.0.81.tar.gz -C /home/"${A_NAME}"
mv /home/${A_NAME}/apache-tomcat-7.0.81/webapps /home/${A_NAME}
chown -R ${A_NAME}:${A_NAME} /home/${A_NAME}

#copy setenv.sh for tomcat
cp /usr/lib/jvm/setenv.sh /home/${A_NAME}/apache-tomcat-7.0.81/bin/

#change ownership of tomcat
/bin/chown -R ${A_NAME}:${A_NAME} /home/${A_NAME}/apache-tomcat-7.0.81/


#edit server.xml
sed -i -e '22 s/8005/-1/' -e '71 s/8080/8081/' -e '125 s#webapps#../webapps#' /home/${A_NAME}/apache-tomcat-7.0.81/conf/server.xml 
sed -i -e '93 s/</<!--/' -e '93 s/>/-->/' /home/${A_NAME}/apache-tomcat-7.0.81/conf/server.xml
sed -i -e '71 s#HTTP/1.1#org.apache.coyote.http11.Http11NioProtocol#' /home/${A_NAME}/apache-tomcat-7.0.81/conf/server.xml

#start tomcat
/bin/su -s /bin/sh - ${A_NAME} -c "cd /home/$A_NAME/apache-tomcat-7.0.81/bin/&&./startup.sh"
#上面这个命令可以简化为
#su - $A_NAME -c "cd apache-tomcat-7.0.81/bin/&&./startup.sh"
#-c command:变更为帐号为USER的使用者并执行指令后再变回原来使用者。command一般用双引号指定
#-s shell:指定要执行的shell,而且参数中必须是shell的完整的路径。如果没有，则默认为/bin/sh,所以这里也可以不写
#-或-l或--login：这个参数加了之后，就好像是重新login为该使用者一样，工作目录也会改变为该用户的家目录

cd 

cat tomcat > /etc/init.d/tomcat
/bin/chmod 755 /etc/init.d/tomcat

chkconfig --add tomcat






#6.  for mysql_crontab
(
cat << EOF
0 0 * * * python /root/mysql_back_up/main.py full
50 * * * * python /root/mysql_back_up/main.py inc
EOF
)>/var/spool/cron/root
/bin/chmod +x /var/spool/cron/root






#7. backup
wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.8/binary/redhat/6/x86_64/percona-xtrabackup-24-2.4.8-1.el6.x86_64.rpm
wget ftp://rpmfind.net/linux/dag/redhat/el6/en/x86_64/dag/RPMS/libev-4.15-1.el6.rf.x86_64.rpm  #依赖包
rpm -ivh libev-4.15-1.el6.rf.x86_64.rpm
yum -y install perl-DBD-mysql #依赖包
yum -y install perl-Digest-MD5 #依赖包

rpm -ivh percona-xtrabackup-24-2.4.8-1.el6.x86_64.rpm






#8. for REDIS
#wget http://download.redis.io/redis-stable.tar.gz
tar xzvf redis-stable.tar.gz
cd redis-stable
yum -y groupinstall "Development Tools"
make
make install
cd utils
./install_server.sh






# download REDIS
#wget http://download.redis.io/redis-stable.tar.gz

# download TOMCAT
#wget https://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-7/v7.0.79/bin/apache-tomcat-7.0.79.tar.gz
