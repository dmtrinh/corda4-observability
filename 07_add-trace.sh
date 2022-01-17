#!/usr/bin/env bash

# Create directories
printf "*********************************************************************************\n"
printf "Create directories\n"
printf "*********************************************************************************\n"

mkdir mynetwork/otelcollector
mkdir {mynetwork/tempo,mynetwork/tempo/tempo-data}

printf "\n"
# Download OpenTelemetry Instrumentation for Java driver
printf "*********************************************************************************\n"
printf "Download OpenTelemetry Instrumentation for Java driver\n"
printf "*********************************************************************************\n"
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.10.0/opentelemetry-javaagent.jar

# Create Log4j Logging configuration
printf "*********************************************************************************\n"
printf "Create Log4j Logging configuration\n"
printf "*********************************************************************************\n"

install -m 644 /dev/null ./mynetwork/shared/logging.xml
cat <<EOF >./mynetwork/shared/logging.xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Appenders>
        <Console name="ConsoleJSONAppender" target="SYSTEM_OUT">
          <JsonLayout complete="false" compact="true"/>
        </Console>
        <File name="FileJSONAppender" fileName="logs/node.json">
          <JsonLayout complete="false" compact="true" properties="true" eventEol="true"/>
        </File>
    </Appenders>
    <Loggers>
        <Logger name="net.corda" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
        </Logger>
        <Logger name="com.r3.corda" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
        </Logger>
        <Logger name="org.hibernate" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
        </Logger>
        <Logger name="org.postgresql" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
        </Logger>
        <Root level="error">
            <AppenderRef ref="FileJSONAppender"/>
        </Root>
    </Loggers>
</Configuration>
EOF

printf "Created in: ./mynetwork/shared/logging.xml\n\n"

# Create the OpenTelemetry Collector configuration
printf "*********************************************************************************\n"
printf "Create the OpenTelemetry Collector configuration\n"
printf "*********************************************************************************\n"

install -m 644 /dev/null ./mynetwork/otelcollector/otel-collector.yaml
cat <<EOF >./mynetwork/otelcollector/otel-collector.yaml
receivers:
  jaeger:
    protocols:
      thrift_http:
  otlp:
    protocols:
      grpc:
      http:
  filelog/node1:
    include: [ /var/bootstrap/partya/logs/*.json ]
    attributes:
      "host.name": partya
  filelog/node2:
    include: [ /var/bootstrap/partyb/logs/*.json ]
    attributes:
      "host.name": partyb
  filelog/notary:
    include: [ /var/bootstrap/notary/logs/*.json ]
    attributes:
      "host.name": notary

processors:
 batch:

exporters:
  otlp:
    endpoint: tempo:55680
    tls:
      insecure: true
  jaeger:
    endpoint: tempo:14250
    tls:
      insecure: true
  zipkin:
    endpoint: "http://zipkin-all-in-one:9411/api/v2/spans"
  prometheus:
    endpoint: "0.0.0.0:9464"

service:
  pipelines:
    traces:
      receivers: [jaeger]
      processors: [batch]
      exporters: [otlp]
    metrics:
      receivers: [otlp]
      exporters: [prometheus]
EOF

printf "Created in: ./mynetwork/otelcollector/otel-collector.yaml\n\n"

# Create the Grafana Tempo configuration
printf "*********************************************************************************\n"
printf "Create the Grafana Tempo configuration\n"
printf "*********************************************************************************\n"

install -m 644 /dev/null ./mynetwork/tempo/tempo-local.yaml
cat <<EOF >./mynetwork/tempo/tempo-local.yaml
auth_enabled: false

server:
  http_listen_port: 3100

distributor:
  receivers:                           # this configuration will listen on all ports and protocols that tempo is capable of.
    jaeger:                            # the receives all come from the OpenTelemetry collector.  more configuration information can
      protocols:                       # be found there: https://github.com/open-telemetry/opentelemetry-collector/tree/master/receiver
        thrift_http:                   #
        grpc:                          # for a production deployment you should only enable the receivers you need!
        thrift_binary:
        thrift_compact:
    zipkin:
    otlp:
      protocols:
        http:
        grpc:
    opencensus:

ingester:
  trace_idle_period: 10s               # the length of time after a trace has not received spans to consider it complete and flush it
  #traces_per_block: 1_000_000
  max_block_duration: 5m               #   this much time passes

compactor:
  compaction:
    compaction_window: 1h              # blocks in this time window will be compacted together
    max_compaction_objects: 1000000    # maximum size of compacted blocks
    block_retention: 1h
    compacted_block_retention: 10m

storage:
  trace:
    backend: local                     # backend configuration to use
    wal:
      path: /tmp/tempo/wal            # where to store the the wal locally
      #bloom_filter_false_positive: .05 # bloom filter false positive rate.  lower values create larger filters but fewer false positives
      #index_downsample: 10             # number of traces per index record
    local:
      path: /tmp/tempo/blocks
    pool:
      max_workers: 100                 # the worker pool mainly drives querying, but is also used for polling the blocklist
      queue_depth: 10000
EOF

printf "Created in: ./mynetwork/tempo/tempo-local.yaml\n\n"

# Create the Grafana Tempo Query configuration
# printf "*********************************************************************************\n"
# printf "Create the Grafana Tempo Query configuration\n"
# printf "*********************************************************************************\n\n"

# install -m 644 /dev/null ./mynetwork/tempo/tempo-query.yaml
# cat <<EOF >./mynetwork/tempo/tempo-query.yaml
# backend: "tempo:3100"
# #backend: "tempo:3102"
# EOF

# printf "Created in: ./mynetwork/tempo/tempo-query.yaml\n\n"

# Create Docker-Compose File
printf "*********************************************************************************\n"
printf "Create Docker-Compose File\n"
printf "*********************************************************************************\n"

cat <<EOF >./mynetwork/docker-compose.trace.yml
version: '3.7'

services:
  otelcollector:
    hostname: otelcollector
    container_name: otelcollector
    image: otel/opentelemetry-collector-contrib:0.42.0
    command: ["--config=/etc/otel-collector.yaml"]
    volumes:
      - ./otelcollector/otel-collector.yaml:/etc/otel-collector.yaml
      - ./partya:/var/bootstrap/partya
      - ./partyb:/var/bootstrap/partyb
      - ./notary:/var/bootstrap/notary
    ports:
      - "4317:4317"      # OLTP/gRPC
      - "4318:4318"      # OLTP/HTTP
      - "9464:9464"      
      #- "55680:55680"
      #- "55681:55681"
#    depends_on:
#      - jaeger-all-in-one
#      - zipkin-all-in-one

  # # Jaeger
  # jaeger-all-in-one:
  #   image: jaegertracing/all-in-one:latest
  #   ports:
  #     - "16686:16686"
  #     - "14268"
  #     - "14250"

#  # Zipkin
#  zipkin-all-in-one:
#    image: openzipkin/zipkin:latest
#    ports:
#      - "9411:9411"

  tempo:
    image: grafana/tempo:1.2.1
    container_name: tempo
    hostname: tempo
    command: ["-config.file=/etc/tempo.yaml"]
    volumes:
      - ./tempo/tempo-local.yaml:/etc/tempo.yaml
      - ./tempo/tempo-data:/tmp/tempo
    restart: unless-stopped  
    ports:
      - "14250:14250"  # Jaeger - GRPC
      - "14268:14268"  # jaeger ingest, Jaeger - Thrift HTTP
      - "55680:55680"  # oltp grpc
      - "55681:55681"  # oltp http
      - "3102:3100"    # tempo

  # tempo-query:
  #   image: grafana/tempo-query:latest
  #   command: ["--grpc-storage-plugin.configuration-file=/etc/tempo-query.yaml"]
  #   volumes:
  #     - ./tempo/tempo-query.yaml:/etc/tempo-query.yaml
  #   ports:
  #     - "16686:16686"  # jaeger-ui
  #   depends_on:
  #     - tempo

  loki:
    extends:
      file: docker-compose.yml
      service: loki
    environment:
      - JAEGER_AGENT_HOST=tempo
      - JAEGER_ENDPOINT=http://tempo:14268/api/traces      # send traces to Tempo
      - JAEGER_SAMPLER_TYPE=const
      - JAEGER_SAMPLER_PARAM=1

  notary:
    extends:
      file: docker-compose.yml
      service: notary
    command: bash -c "java -Dlog4j.configurationFile=/opt/corda/logging.xml -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas --allow-hibernate-to-manage-app-schema && /opt/corda/bin/run-corda"
    volumes:
      - ./shared/logging.xml:/opt/corda/logging.xml:ro
    environment:
      ## Notice use of JVM_ARGS in https://github.com/corda/corda/blob/release/os/4.9/docker/src/bash/run-corda.sh
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -Dlog4j.configurationFile=/opt/corda/logging.xml -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/config.yml -javaagent:/opt/corda/drivers/opentelemetry-javaagent.jar"
#      - "CORDA_ARGS=\"--logging-level=INFO\""
      - OTEL_SERVICE_NAME=corda-partya
      - OTEL_EXPORTER=otlp_span                            # TODO confirm valid env var
      - OTEL_TRACES_EXPORTER=jaeger                        # default is oltp
      - OTEL_EXPORTER_JAEGER_ENDPOINT=http://tempo:14250
      - "OTEL_RESOURCE_ATTRIBUTES=\"host.hostname=partya\""

  partya:
    extends:
      file: docker-compose.yml
      service: partya
    command: bash -c "java -Dlog4j.configurationFile=/opt/corda/logging.xml -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas --allow-hibernate-to-manage-app-schema && /opt/corda/bin/run-corda"
    volumes:
      - ./shared/logging.xml:/opt/corda/logging.xml:ro
    environment:
      ## Notice use of JVM_ARGS in https://github.com/corda/corda/blob/release/os/4.9/docker/src/bash/run-corda.sh
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -Dlog4j.configurationFile=/opt/corda/logging.xml -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/config.yml -javaagent:/opt/corda/drivers/opentelemetry-javaagent.jar"
#      - "CORDA_ARGS=\"--logging-level=INFO\""
      - OTEL_SERVICE_NAME=corda-partya
      - OTEL_EXPORTER=otlp_span                            # TODO confirm valid env var
      - OTEL_TRACES_EXPORTER=jaeger                        # default is oltp
      - OTEL_EXPORTER_JAEGER_ENDPOINT=http://tempo:14250
      - "OTEL_RESOURCE_ATTRIBUTES=\"host.hostname=partya\""

  partyb:
    extends:
      file: docker-compose.yml
      service: partyb
    command: bash -c "java -Dlog4j.configurationFile=/opt/corda/logging.xml -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas --allow-hibernate-to-manage-app-schema && /opt/corda/bin/run-corda"
    volumes:
      - ./shared/logging.xml:/opt/corda/logging.xml:ro
    environment:
      ## Notice use of JVM_ARGS in https://github.com/corda/corda/blob/release/os/4.9/docker/src/bash/run-corda.sh
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -Dlog4j.configurationFile=/opt/corda/logging.xml -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/config.yml -javaagent:/opt/corda/drivers/opentelemetry-javaagent.jar"
#      - "CORDA_ARGS=\"--logging-level=INFO\""
      - OTEL_SERVICE_NAME=corda-partyb
      - OTEL_EXPORTER=otlp_span                            # TODO confirm valid env var
      - OTEL_TRACES_EXPORTER=jaeger                        # default is oltp
      - OTEL_EXPORTER_JAEGER_ENDPOINT=http://tempo:14250
      - "OTEL_RESOURCE_ATTRIBUTES=\"host.hostname=partyb\""
EOF

printf "Created in: ./mynetwork/docker-compose.trace.yml\n"

printf "Run command: docker compose -f ./mynetwork/docker-compose.trace.yml up -d\n\n"

printf "*********************************************************************************\n"
printf "COMPLETE\n"
printf "*********************************************************************************\n"
