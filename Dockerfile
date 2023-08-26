FROM centos:7                       
MAINTAINER hong                      
WORKDIR /usr                       
RUN yum install -y vim            
 
CMD /bin/bash     
