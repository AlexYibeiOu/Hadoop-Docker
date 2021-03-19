#!/bin/bash


echo "1. Check installation of docker-connector..."
brew install wenjunxiao/brew/docker-connector
echo "docker-connector Installed!"
echo ""


echo "2. Configuring..."
sed -i '' '/expose/d' /usr/local/etc/docker-connector.conf
sed -i '' '/token/d' /usr/local/etc/docker-connector.conf
docker network ls --filter driver=bridge --format "{{.ID}}" | xargs docker network inspect --format "route {{range .IPAM.Config}}{{.Subnet}}{{end}} expose" >> /usr/local/etc/docker-connector.conf
echo "Finish configuration!"
echo ""


echo "3. Start docker-connector..."
sudo brew services start docker-connector
echo "Docker-connector service is running!"
echo ""


echo "4. Starting Docker Daemon..."
open -a Docker
closed=1
while [ $closed -eq 1 ]
do
    sleep 1 
    docker info >> /dev/null 2>&1 
    closed=$?
done
echo "Docker Daemon is ready!"
echo ""


echo "5. Checking container"
#docker ps -a | grep connector | awk '{ if (!(/Up/)) { system("/home/xxx/send_mail.sh") }}'
docker ps -a | grep connector 
if [ $? -eq 1 ]     # container not exist
then 
    echo "Container not exist, create new container..."
    docker run -it -d --restart always --net host --cap-add NET_ADMIN --name connector wenjunxiao/mac-docker-connector
else
    docker ps -a | grep connector | grep Up >> /dev/null
    if [ $? -eq 1 ]
    then
        echo "Container already exist, restarting..."
        docker restart connector
    fi
fi
echo "container is running!"
echo ""

accessor_installed=""
echo "6. Check installation of docker-accessor"
accessor_installed=`brew list | grep docker-accessor`
if [ "$accessor_installed" = "" ]
then
    brew install wenjunxiao/brew/docker-accessor
fi
echo "docker-accessor installed!"
echo ""

echo "7. Starting docker-accessor service..."
nohup docker-accessor -remote 192.168.1.104:2512 -token user1 &
echo "docker-accesor is running."
echo ""

echo "Congratulations! Containers are ready for access by IP!"