Hadoop cluster using Docker
==========
This repository contains Docker file to build a Docker image with Hadoop, Spark, HBase, Hive, Zookeeper and Kafka. The accompanying scripts can be used to start and stop the clusters easily.

This repository is combined and improved by below two repositories:

https://github.com/DenivaldoCruz/dcruz-hadoop-cluster
It offers hadoop cluster on docker.

https://github.com/wenjunxiao/mac-docker-connector
It provide a connector to asscess containers by IP Address.

My improvement at the moment is:
1 Built in Spark Cluster


## Pull the image

The image is released as an official Docker image from Docker's automated build repository - you can always pull or refer the image when launching containers.
```
docker pull denivaldocruz/hadoop_cluster
```

## Build the image

If you would like to try directly from the Dockerfile you can build the image as:
```
docker build --rm --no-cache -t denivaldocruz/hadoop_cluster .
```

# Create network, containers and start cluster

## Through script
You can use the start_cluster.sh and stop_cluster.sh scripts to start and stop the hadoop cluster using bash or Windows Powershell.
* Default is 1 namenode with 2 datanodes (upto 8 datanodes currently possible, to add more edit "/usr/local/hadoop/etc/hadoop/slaves" and restart the cluster)
* Each node takes 1GB memory and 2 virtual cpu cores
```
sh start_cluster.sh 2
sh stop_cluster.sh
```
## Manual procedure
### Create bridge network
```
docker network create --driver bridge hadoop
```
### Create and start containers
Create a namenode container with the Docker image you have just built or pulled
```
docker create -it -p 8088:8088 -p 50070:50070 -p 50075:50075 -p 2122:2122 -p 8080:8080 -p 4000:4000 --net hadoop --name namenode --hostname namenode --memory 1024m --cpus 2 denivaldocruz/hadoop_cluster
```
8080 & 4000 for spark

Create and start datanode containers with the Docker image you have just built or pulled (upto 8 datanodes currently possible, to add more edit "/usr/local/hadoop/etc/hadoop/slaves" and restart the cluster)

```
docker run -itd --name datanode1 --net hadoop --hostname datanode1 --memory 1024m --cpus 2 denivaldocruz/hadoop_cluster
docker run -itd --name datanode2 --net hadoop --hostname datanode2 --memory 1024m --cpus 2 denivaldocruz/hadoop_cluster
...
```
Start namenode container
```
docker start namenode
```
### Start cluster
```
docker exec -it namenode //etc//bootstrap.sh start_cluster
```

After few minutes, you should be able to view Resource Manager UI at

http://<host>:8088

You should be able to access the HDFS UI at

http://<host>:50070

## Credentials
You can connect through SSH and SFTP clients to the namenode of the cluster using port 2122
```
Username: hdpuser
Password: hdppassword
```

### Miscellaneous information
* You can login as root user into namenode using "docker exec -it namenode bash"
* To start HBase manually, log in as root (as described above) and executing the command "$HBASE_HOME/bin/start-hbase.sh"
* To start Kafka manually, log in as root (as described above) and executing the command "$KAFKA_HOME/bin/kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties"
* Kafka topics can be created by "hdpuser" with root priviledges
```
sudo $KAFKA_HOME/bin/kafka-topics.sh --create --zookeeper namenode:2181 --replication-factor 1 --partitions 1 --topic test

$KAFKA_HOME/bin/kafka-topics.sh --create --zookeeper namenode:2181 --replication-factor 1 --partitions 3 --topic msgtopic

$KAFKA_HOME/bin/kafka-console-producer.sh --broker-list namenode:9092 --topic msgtopic

$KAFKA_HOME/bin/kafka-console-consumer.sh --bootstrap-server namenode:9092 --topic msgtopic --from-beginning
```
### Known issues
* Spark application master is not reachable from host system
* HBase and Kafka services do not start automatically sometimes (increasing memory of the container might solve this issue)
* No proper PySpark setup
* Unable to get Hive to work on Tez (current default MapReduce)

# Spark Cluster

1. spark-env.sh

   ```
   cd /usr/local/spark
   cp spark-env.sh.template spark-env.sh
   vi spark-env.sh 
   
   #append below:
   
   export JAVA_HOME=/usr/local/java
   
   export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=4000 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark_log"
   
   export SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=ZOOKEEPER  -Dspark.deploy.zookeeper.url=namenode:2181  -Dspark.deploy.zookeeper.dir=/spark"
   ```

   In shell script: setup_spark_env.sh

   ```shell
   #!/bin/bash
   
   cp /usr/local/spark/conf/spark-env.sh.template /usr/local/spark/conf/spark-env.sh
   
   echo 'export JAVA_HOME=/usr/local/java' >> /usr/local/spark/conf/spark-env.sh
   
   echo 'export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=4000 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark_log"' >> /usr/local/spark/conf/spark-env.sh
   
   echo 'export SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=ZOOKEEPER  -Dspark.deploy.zookeeper.url=namenode:2181  -Dspark.deploy.zookeeper.dir=/spark"' >> /usr/local/spark/conf/spark-env.sh
   ```

2. slaves

   ```
   cp  slaves.template slaves
   vi slaves
   
   # delete localhost
   # append below:
   namenode
   datanode1
   datanode2
   ```

   In shell script: setup_slaves.sh

   ```shell
   #!/bin/bash
   
   cp /usr/local/spark/conf/slaves.template /usr/local/spark/conf/slaves
   
   sudo sed -i '/localhost/d' /usr/local/spark/conf/slaves
   
   echo 'namenode' >> /usr/local/spark/conf/slaves
   echo 'datanode1' >> /usr/local/spark/conf/slaves
   echo 'datanode2' >> /usr/local/spark/conf/slaves
   ```

3. spark-defaults.conf

   ```
   cp spark-defaults.conf.template spark-defaults.conf
   vi spark-defaults.conf
   
   # append below
   spark.master            spark://namenode:7077
   spark.eventLog.enabled  true
   spark.eventLog.dir      hdfs://namenode:9000/spark_log
   spark.eventLog.compress true
   ```

   In shell script: setup_spark_defaults.conf.sh

   ```shell
   #!/bin/bash
   
   cp /usr/local/spark/conf/spark-defaults.conf.template /usr/local/spark/conf/spark-defaults.conf
   
   echo 'spark.master            spark://namenode:7077' >> /usr/local/spark/conf/spark-defaults.conf
   echo 'spark.eventLog.enabled  true' >> /usr/local/spark/conf/spark-defaults.conf
   echo 'spark.eventLog.dir      hdfs://namenode:9000/spark_log' >> /usr/local/spark/conf/spark-defaults.conf
   echo 'spark.eventLog.compress true' >> /usr/local/spark/conf/spark-defaults.conf
   ```

   

4. copy to datanodes and create HDFS log file

   ```
   cd /usr/local/
   scp -r spark/ datanode1:$PWD
   scp -r spark/ datanode2:$PWD
   
   
   hdfs  dfs -mkdir -p /spark_log
   ```

   In shell script: setup_spark_cluster.sh

   ```sh
   #!/bin/bash
   
   
   # setup_spark_env.sh
   cp /usr/local/spark/conf/spark-env.sh.template /usr/local/spark/conf/spark-env.sh
   echo 'export JAVA_HOME=/usr/local/java' >> /usr/local/spark/conf/spark-env.sh
   echo 'export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=4000 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark_log"' >> /usr/local/spark/conf/spark-env.sh
   echo 'export SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=ZOOKEEPER  -Dspark.deploy.zookeeper.url=namenode:2181  -Dspark.deploy.zookeeper.dir=/spark"' >> /usr/local/spark/conf/spark-env.sh
   
   
   #sh setup_slaves.sh
   cp /usr/local/spark/conf/slaves.template /usr/local/spark/conf/slaves
   sudo sed -i '/localhost/d' /usr/local/spark/conf/slaves
   echo 'namenode' >> /usr/local/spark/conf/slaves
   echo 'datanode1' >> /usr/local/spark/conf/slaves
   echo 'datanode2' >> /usr/local/spark/conf/slaves
   
   
   #sh setup_spark_defaults.conf.sh
   cp /usr/local/spark/conf/spark-defaults.conf.template /usr/local/spark/conf/spark-defaults.conf
   echo 'spark.master            spark://namenode:7077' >> /usr/local/spark/conf/spark-defaults.conf
   echo 'spark.eventLog.enabled  true' >> /usr/local/spark/conf/spark-defaults.conf
   echo 'spark.eventLog.dir      hdfs://namenode:9000/spark_log' >> /usr/local/spark/conf/spark-defaults.conf
   echo 'spark.eventLog.compress true' >> /usr/local/spark/conf/spark-defaults.conf
   
   
   # copy to datanodes
   scp -r /usr/local/spark/ datanode1:$PWD
   scp -r /usr/local/spark/ datanode2:$PWD
   
   
   # create HDFS log file
   hdfs  dfs -mkdir -p /spark_log
   ```

5. start master with -h [namenode ip]

   ```
   sbin/start-master
   ```

   To get ip address

   ```
   ifconfig
   
   look for 'inet addr:'
   ```

6. Start spark cluster

   ```
   $SPARK_HOME/sbin/start-all.sh
   $SPARK_HOME/sbin/start-history-server.sh
   ```

7. spark webUI

   - master web:    http://localhost:8080/

   - historyserver:    http://localhost:4000/

8. Stop spark cluster

   ```
   $SPARK_HOME/sbin/stop-all.sh
   ```


