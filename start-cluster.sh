#!/bin/bash

# Start connector
echo "Start Cluster Step 1 (total 5 steps):"
echo "Start connector..."
sh connector_start.sh
echo "connector running"
echo ""

# the default node number is 2
N=${1:-2}

tag="latest"
if [ ! -z "$2" ]; then
	tag=$2 
fi

echo "Start Cluster Step 2 (total 5 steps):"
echo "Checking Docker network..."
if  ! docker network ls | grep -q 'hadoop'; then
    echo "Creating Docker network..."
    docker network create --driver bridge hadoop
else
    echo "Hadoop network exists"
fi
echo ""

# Create namenode container
First_Create=0
echo "Start Cluster Step 3 (total 5 steps):"
echo "Check existing namenode container..."
if  ! docker container ls -a | grep -q 'namenode'; then
    echo "Creating namenode container..."
    First_Create=1
    # docker create -it -p 8088:8088 -p 4040:4040 -p 50070:50070 -p 50075:50075 -p 2122:2122 -p 8080:8080 -p 4000:4000 --net hadoop --name namenode --hostname namenode --memory 1024m --cpus 2 denivaldocruz/hadoop_cluster:$tag
    # docker create -it --net hadoop --name namenode --hostname namenode --memory 1024m --cpus 2 denivaldocruz/hadoop_cluster:$tag
    # Below without setting memory limitaion
    docker create -it --net hadoop --name namenode --hostname namenode --cpus 2 denivaldocruz/hadoop_cluster:$tag
else
    echo "Namenode container exists"
fi
echo ""

# Create [if does not exist] and start hadoop slave containers
for i in $(seq 1 $N)
do
    # Create datanode container
    echo "Check existing datanode$i container..."
    if  ! docker container ls -a | grep -q "datanode$i"; then
        echo "Creating and starting datanode$i container..."
        # docker run -itd --name datanode$i --net hadoop --hostname datanode$i --memory 1024m --cpus 2 denivaldocruz/hadoop_cluster:$tag
        # Below without setting memory limitaion
        docker run -itd --name datanode$i --net hadoop --hostname datanode$i --cpus 2 denivaldocruz/hadoop_cluster:$tag
    else
        echo "Starting datanode$i container"
        docker start datanode$i
    fi
done
ehco ""

echo "Start Cluster Step 4 (total 5 steps):"
echo "Starting namenode container..."
docker start namenode
# update bootstrap.sh to namenode
docker cp ./bootstrap.sh namenode:/etc/bootstrap.sh
docker cp ./xcall namenode:/bin/xcall
docker cp ./yarn-site.xml namenode:/usr/local/hadoop/etc/hadoop/yarn-site.xml
docker cp ./yarn-site.xml datanode1:/usr/local/hadoop/etc/hadoop/yarn-site.xml
docker cp ./yarn-site.xml datanode2:/usr/local/hadoop/etc/hadoop/yarn-site.xml
echo ""

echo "Start Cluster Step 5 (total 5 steps):"
echo "Starting hadoop cluster..."
docker exec -it namenode //etc//bootstrap.sh start_cluster

if [ $First_Create -eq 1 ]; then
    echo "First create cluster, Starting setup Spark Cluster..."
    docker cp ./setup-spark-cluster.sh namenode:/usr/local/spark/bin/
    docker exec namenode /usr/local/spark/bin/setup-spark-cluster.sh
    docker cp ./spark-start-cluster.sh namenode:/usr/local/spark/sbin/
    docker cp ./spark-stop-cluster.sh namenode:/usr/local/spark/sbin/
    docker exec namenode chmod 755 /usr/loca/spark/sbin/spark-start-cluster.sh
    docker exec namenode chmod 755 /usr/loca/spark/sbin/spark-stop-cluster.sh
fi
echo ""


echo "You can check Resource Manager UI at <DOCKER_HOST>:8088 and HDFS UI at <DOCKER_HOST>:50070"
echo "You can login using any SSH and SFTP client on port 2122 using username 'hdpuser' and password 'hdppassword'"

