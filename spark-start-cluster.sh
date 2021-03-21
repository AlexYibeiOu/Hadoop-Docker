#!/bin/bash

# This shell script file will be uploat to namenode:/usr/local/spark/sbin/


# This shell script file is also called by start-cluster.sh

echo "Starting Spark Cluster: Master X 1, Worker X 3"
/usr/local/spark/sbin/start-all.sh
echo ""

echo "Starting Spark History Server"
/usr/local/spark/sbin/start-history-server.sh
echo ""

/bin/xcall jps

echo ""

echo "Spark Server http://namenode:8080"

echo ""

echo "Spark History Server http://namenode:4000"