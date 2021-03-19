#!/bin/bash

# This shell script file will be uploat to namenode:/usr/local/spark/sbin/


# This shell script file is also called by start-cluster.sh

/usr/local/spark/sbin/start-all.sh

/usr/local/spark/sbin/start-history-server.sh

/bin/xcall jps