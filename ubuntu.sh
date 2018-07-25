#!/bin/bash

#first, change to root

#出错立刻中断
set -e

apt-get update
#useful tools
apt-get -y install build-essential libssl-dev libcurl4-openssl-dev unzip makepasswd lrzsz \
           language-pack-zh-hans-base python-pip python-dev libev-dev pwgen expect

#apt-get libxp6 有时候apt找不到

		   
#1. auto scp software from aliyun

#/usr/bin/expect <<EOF   SCP拷贝，这种方式老是传一半出错。
#set ip 47.52.136.86
#set pass Jinhong@125

#spawn ssh root@$ip
#spawn scp -r root@$ip:/root/UBUNTU .
#expect {
#        "(yes/no)" {send "yes\r"; exp_continue}
#       " password: " {send "$pass\r"}
#}

#expect "*#" {send "df -h\r"}
#expect "*#" {send "exit\r"}
#expect eof

#EOF

#rsync支持断点续传
rsync -rP --rsh=ssh 47.52.136.86:/root/UBUNTU/ /root

echo "nameserver 114.114.114.114" >> /etc/resolvconf/resolv.conf.d/base
resolvconf -u


	   

#2. this script is for creating a new user  

#这里需要先清空/home目录下的非用户文件夹
#A_NAME=$(ls /home)
A_NAME=$(grep 1000 /etc/passwd | cut -d: -f 1)
if [ -n "${A_NAME} ];then
su - ${A_NAME} -c "mkdir axinfu && cd axinfu && mkdir mgrfilepath cert accountfile config"
else
useradd axinfu
su - axinfu -c "mkdir axinfu && cd axinfu && mkdir mgrfilepath cert accountfile config"
fi

A_NAME=$(grep 1000 /etc/passwd | cut -d: -f 1)

#上面这种方法并不是通用的，再说一种，登陆到普通用户后，echo $USER即可得到普通用户名，或者echo $HOME | cut -d "/" -f 3




#3. this script is for JDK
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
#cat >> /etc/profile << EOF
#LINE 1
#LINE 2
#EOF

source /etc/profile





#4.for tomcat
tar xzvf apache-tomcat-7.0.81.tar.gz -C /home/"${A_NAME}"
mv /home/$A_NAME/apache-tomcat-7.0.81/webapps /home/$A_NAME
chown -R $A_NAME:$A_NAME /home/$A_NAME/webapps

#copy setenv.sh for tomcat
cp /usr/lib/jvm/setenv.sh /home/$A_NAME/apache-tomcat-7.0.81/bin/

#change ownership of tomcat
/bin/chown -R $A_NAME:$A_NAME /home/$A_NAME/apache-tomcat-7.0.81/


#edit server.xml
sed -i -e '22 s/8005/-1/' -e '71 s/8080/8081/' -e '125 s#webapps#../webapps#' /home/$A_NAME/apache-tomcat-7.0.81/conf/server.xml 
sed -i -e '93 s/</<!--/' -e '93 s/>/-->/' /home/$A_NAME/apache-tomcat-7.0.81/conf/server.xml

sed -i -e '71 s#HTTP/1.1#org.apache.coyote.http11.Http11NioProtocol#' /home/$A_NAME/apache-tomcat-7.0.81/conf/server.xml

#start tomcat
/bin/su -s /bin/sh - $A_NAME -c "cd /home/$A_NAME/apache-tomcat-7.0.81/bin/&&./startup.sh"
#上面这个命令可以简化为
#su - $A_NAME -c "cd apache-tomcat-7.0.81/bin/&&./startup.sh"
#-c command:变更为帐号为USER的使用者并执行指令后再变回原来使用者。command一般用双引号指定
#-s shell:指定要执行的shell,而且参数中必须是shell的完整的路径。如果没有，则默认为/bin/sh,所以这里也可以不写
#-或-l或--login：这个参数加了之后，就好像是重新login为该使用者一样，工作目录也会改变为该用户的家目录


cat tomcat > /etc/init.d/tomcat
/bin/chmod 755 /etc/init.d/tomcat

#add to startlist
update-rc.d tomcat defaults 95 





#5. for crontab
(
cat << EOF
0 0 * * * python /root/mysql_back_up/main.py full
50 * * * * python /root/mysql_back_up/main.py inc
EOF
)>/var/spool/cron/crontabs/root
/bin/chmod +x /var/spool/cron/crontabs/root





#6. collect info
CPU=$(lscpu | sed -n '4p' | awk -F "[ ]+" '{print $2}')
BLK=$(lsblk | grep disk | awk -F "[ ]+" '{print $4}')
RAM=$(free -g | grep Mem | awk -F "[ ]+" '{print $2}')
PLATFORM=$(dmidecode -s system-product-name)

(
cat << EOF
cpu:$CPU
disk:$BLK
ram:$RAM
platform:$PLATFORM

EOF
)>INFO

cat /proc/scsi/scsi | grep Vendor >> INFO
echo -e "\n" >> INFO
cat /proc/version >> INFO

#create 3 password
pwgen -Bs 10 3 > secret.txt



#7. for mysql

exist=$(dpkg -l | grep mysql) # 若没有返回，说明已完成卸载
if [ -n "$exist" ]; then
#uninstll mysql5.5
apt-get -y autoremove --purge mysql-server-5.*
apt-get -y remove mysql-common
dpkg -l |grep ^rc|awk '{print $2}' | xargs dpkg -P
fi

#install mysql5.6    http://blog.csdn.net/u011304615/article/details/68942115
echo 'mysql-server-5.6 mysql-server/root_password password 123' | debconf-set-selections
echo 'mysql-server-5.6 mysql-server/root_password_again password 123' | debconf-set-selections
#apt-get install mysql-client-core-5.6 mysql-client-5.6 mysql-server-5.6 -y 这种安装方式修改字符集会启动不了mysql

#ubuntu16不能装mysql5.6，解决方法
#apt-get install software-properties-common
#add-apt-repository -y ppa:ondrej/mysql-5.6
#apt-get update
apt-get install -y mysql-server-5.6 mysql-client-5.6 libmysqlclient-dev

#在[mysqld]行后面加入内容，解决不同版本[mysqld]行数不同的问题

sed -ir '/\[mysqld\]/ a character-set-server=utf8 \nbinlog-format=row' /etc/mysql/my.cnf
service mysql restart

mysql -uroot -p123 -e "GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'bak'@'localhost' IDENTIFIED BY 'axfchonga';FLUSH PRIVILEGES"




#8. for backup

wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.8/binary/debian/trusty/x86_64/percona-xtrabackup-24_2.4.8-1.trusty_amd64.deb
dpkg -i percona-xtrabackup-24_2.4.8-1.trusty_amd64.deb





#9. this script is for REDIS
tar xzvf redis-stable.tar.gz
cd redis-stable
#yum -y groupinstall "Development Tools"
make
make install
cd utils
/usr/bin/expect <<EOF
spawn ./install_server.sh
expect "*6379*" {send "\r"}
expect "*conf*" {send "\r"}
expect "*log*" {send "\r"}
expect "*var/lib*" {send "\r"}
expect "*server*" {send "\r"}
expect "*ok*" {send "\r"}
expect eof

EOF



9. #others

mysql_secure_installation







