#!/bin/bash

echo "1. Stopping spark cluster..."
sh spark_stop_cluster.sh
echo "spark cluster stopped."
echo ""

# the default node number is 2
N=${1:-2}

# Stop namenode container
echo "2. Check existing namenode container..."
if docker container ls -a | grep -q 'namenode'; then
    echo "Stopping cluster..."
    docker exec -it namenode //etc//bootstrap.sh stop_cluster
    echo "Stopping namenode container..."
    docker stop namenode
fi
echo "namenode stopped."
echo ""

# Stopping hadoop slave containers
echo "3. Stopping datanode containers..."
docker stop $(docker container ls -a | grep 'datanode[1-8]' | awk '{print $1}')
echo "datanodes stopped."
echo ""


echo "4. Stopping connector..."
sh connector_stop.sh
echo "connector stopped."
echo ""

echo 'All containers stopped'
