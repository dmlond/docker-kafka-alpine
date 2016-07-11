#!/bin/bash

if [[ -z "$KAFKA_PORT" ]]; then
    export KAFKA_PORT=9092
fi
if [[ -z "$KAFKA_ADVERTISED_PORT" ]]; then
    advertised_port=$(docker port `hostname` $KAFKA_PORT | sed -r "s/.*:(.*)/\1/g")
    if [[ -z advertised_port ]]; then
        export KAFKA_ADVERTISED_PORT=$(docker port `hostname` $KAFKA_PORT | sed -r "s/.*:(.*)/\1/g")
    fi
fi
if [[ -z "$KAFKA_BROKER_ID" ]]; then
    # By default auto allocate broker ID
    export KAFKA_BROKER_ID=-1
fi
if [[ -z "$KAFKA_LOG_DIRS" ]]; then
    export KAFKA_LOG_DIRS="/kafka/kafka-logs/$HOSTNAME"
fi
if [[ -z "$KAFKA_ZOOKEEPER_CONNECT" ]]; then
    export KAFKA_ZOOKEEPER_CONNECT=$(env | grep ZOOKEEPER_PORT_2181_TCP= | sed -e 's|.*tcp://||' | paste -sd ,)
fi

if [[ -n "$KAFKA_HEAP_OPTS" ]]; then
    sed -r -i "s/(export KAFKA_HEAP_OPTS)=\"(.*)\"/\1=\"$KAFKA_HEAP_OPTS\"/g"
    bin/kafka-server-start.sh
    unset KAFKA_HEAP_OPTS
fi

if [[ -z "$KAFKA_ADVERTISED_HOST_NAME" && -n "$HOSTNAME_COMMAND" ]]; then
    export KAFKA_ADVERTISED_HOST_NAME=$(eval $HOSTNAME_COMMAND)
fi

for VAR in `env`
do
  if [[ $VAR =~ ^KAFKA_ ]]; then
    kafka_name=`echo "$VAR" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
    env_var=`echo "$VAR" | sed -r "s/(.*)=.*/\1/g"`
    if egrep -q "(^|^#)$kafka_name=" config/server.properties; then
        sed -r -i "s@(^|^#)($kafka_name)=(.*)@\2=${!env_var}@g" config/server.properties #note that no config values may contain an '@' char
    else
        echo "$kafka_name=${!env_var}" >> config/server.properties
    fi
  fi
done

# Make logs dirs
mkdir -p $KAFKA_LOG_DIRS
chown -R kafka:kafka $KAFKA_LOG_DIRS

# KAFKA_PID=0
#
# # see https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86#.bh35ir4u5
# term_handler() {
#   echo 'Stopping Kafka....'
#   if [ $KAFKA_PID -ne 0 ]; then
#     kill -s TERM "$KAFKA_PID"
#     wait "$KAFKA_PID"
#   fi
#   echo 'Kafka stopped.'
#   exit
# }
#
#
# # Capture kill requests to stop properly
# trap "term_handler" SIGHUP SIGINT SIGTERM
# create-topics.sh &
# $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties &
# KAFKA_PID=$!
#
# wait
