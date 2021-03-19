#!/bin/bash

echo "1. Killing process docker-accessor..."
process_name="docker-accessor"

PIDCOUNT=`ps -ef | grep $process_name | grep -v "grep" | grep -v $0 | awk '{print $2}' | wc -l`;  
if [ ${PIDCOUNT} -gt 1 ] ; then  
    echo "There are too many process contains name[$process_name]"  
elif [ ${PIDCOUNT} -le 0 ] ; then  
    echo "No such process[$process_name]!"  
else  
    PID=`ps -ef | grep $process_name | grep -v "grep" | grep -v ".sh" | awk '{print $2}'` ;  
    echo "Find the PID of this progress!--- process:$process_name PID=[${PID}] ";  
    echo "Kill the process $process_name ...";  
    kill -9  ${PID};  
    echo "kill -9 ${PID} $process_name done!";  
fi  
echo "Process killed!"
echo ""

echo "2. Stopping container..."
docker stop connector
echo "Container stopped!"
echo ""

echo "3. Stopping service docker-connector..."
sudo brew services stop docker-connector
echo "Service stopped."
echo ""

echo "All services stopped."