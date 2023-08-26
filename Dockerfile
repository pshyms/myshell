FROM ubuntu
RUN apt-get update
RUN apt-get install -y nginx
EXPOSE 80
ENTRYPOINT ["/usr/sbin/nginx","-g",daemon off;"]
