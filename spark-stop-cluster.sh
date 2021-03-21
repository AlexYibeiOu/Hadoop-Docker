#!/bin/bash

# This shell script file will be uploat to namenode:/usr/local/spark/sbin/

# This shell script file is also called by start-cluster.sh

echo "Stopping Spark History Server..."
/usr/local/spark/sbin/stop-history-server.sh

echo "Stopping Spark Cluster..."
/usr/local/spark/sbin/stop-all.sh

