#!/bin/bash

# This shell script file will be uploat to namenode:/usr/local/spark/bin/

# This shell script file is also called by start-cluster.sh

# setup_spark_env.sh
echo "Setup Spark Cluster - Step 1 (total 5 steps):"
echo "Configuring spark-env.sh..."
cp /usr/local/spark/conf/spark-env.sh.template /usr/local/spark/conf/spark-env.sh
echo 'export JAVA_HOME=/usr/local/java' >> /usr/local/spark/conf/spark-env.sh
echo 'export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=4000 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark_log"' >> /usr/local/spark/conf/spark-env.sh
echo 'export SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=ZOOKEEPER  -Dspark.deploy.zookeeper.url=namenode:2181  -Dspark.deploy.zookeeper.dir=/spark"' >> /usr/local/spark/conf/spark-env.sh
echo ""

#sh setup_slaves.sh
echo "Setup Spark Cluster - Step 2 (total 5 steps):"
echo "Configuring slaves..."
cp /usr/local/spark/conf/slaves.template /usr/local/spark/conf/slaves 
sudo sed -i '/localhost/d' /usr/local/spark/conf/slaves
echo 'namenode' >> /usr/local/spark/conf/slaves
echo 'datanode1' >> /usr/local/spark/conf/slaves
echo 'datanode2' >> /usr/local/spark/conf/slaves
echo ""

#sh setup_spark_defaults.conf.sh
echo "Setup Spark Cluster - Step 3 (total 5 steps):"
echo "Configuring spark-defaults.conf..."
cp /usr/local/spark/conf/spark-defaults.conf.template /usr/local/spark/conf/spark-defaults.conf
echo 'spark.master            spark://namenode:7077' >> /usr/local/spark/conf/spark-defaults.conf
echo 'spark.eventLog.enabled  true' >> /usr/local/spark/conf/spark-defaults.conf
echo 'spark.eventLog.dir      hdfs://namenode:9000/spark_log' >> /usr/local/spark/conf/spark-defaults.conf
echo 'spark.eventLog.compress true' >> /usr/local/spark/conf/spark-defaults.conf
echo ""

# copy to datanodes
echo "Setup Spark Cluster - Step 4 (total 5 steps):"
echo "scp to datanode1 & datanode2"
scp -r /usr/local/spark/ datanode1:$PWD >> /dev/null
scp -r /usr/local/spark/ datanode2:$PWD >> /dev/null
echo ""

# create HDFS log file
echo "Setup Spark Cluster - Step 5 (total 5 steps):"
echo "Create log file"
hdfs  dfs -mkdir -p /spark_log
echo ""