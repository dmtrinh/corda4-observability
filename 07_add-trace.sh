#!/usr/bin/env bash

# Create directories
printf "*********************************************************************************\n"
printf "Create directories\n"
printf "*********************************************************************************\n"

mkdir mynetwork/shared/tools
mkdir mynetwork/otelcollector
mkdir {mynetwork/tempo,mynetwork/tempo/tempo-data}

# Download auxiliary Corda tools
printf "*********************************************************************************\n"
printf "Download auxiliary Corda tools \n"
printf "*********************************************************************************\n"
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/tools https://software.r3.com/artifactory/corda-releases/net/corda/corda-tools-explorer/4.8.6/corda-tools-explorer-4.8.6.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/tools https://software.r3.com:443/artifactory/corda/net/corda/corda-tools-blob-inspector/4.8.6/corda-tools-blob-inspector-4.8.6.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/tools https://software.r3.com:443/artifactory/corda-releases/net/corda/corda-tools-checkpoint-agent/4.8.6/corda-tools-checkpoint-agent-4.8.6.jar

# Download OpenTelemetry Instrumentation for Java driver
printf "*********************************************************************************\n"
printf "Download OpenTelemetry Instrumentation for Java \n"
printf "*********************************************************************************\n"
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.10.0/opentelemetry-javaagent.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://repo1.maven.org/maven2/io/opentelemetry/opentelemetry-api/1.10.1/opentelemetry-api-1.10.1.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://repo1.maven.org/maven2/io/opentelemetry/opentelemetry-sdk/1.10.1/opentelemetry-sdk-1.10.1.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://repo1.maven.org/maven2/io/opentelemetry/opentelemetry-sdk-trace/1.10.1/opentelemetry-sdk-trace-1.10.1.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://repo1.maven.org/maven2/io/opentelemetry/opentelemetry-context/1.10.1/opentelemetry-context-1.10.1.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://repo1.maven.org/maven2/io/opentelemetry/instrumentation/opentelemetry-log4j-2.13.2/1.9.2-alpha/opentelemetry-log4j-2.13.2-1.9.2-alpha.jar
wget -N --https-only --progress=bar -N --continue -P ./mynetwork/shared/drivers https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-layout-template-json/2.17.1/log4j-layout-template-json-2.17.1.jar

# Overwrite the Prometheus driver config
printf "*********************************************************************************\n"
printf "Overwrite the Prometheus driver config\n"
printf "*********************************************************************************\n"

install -m 644 /dev/null ./mynetwork/shared/drivers/prom_jmx_exporter.yaml
cat <<EOF >./mynetwork/shared/drivers/prom_jmx_exporter.yaml
# Reference @ https://github.com/prometheus/jmx_exporter
# ---
# rules:
#   # net.corda<type=Caches, component=NodeVaultService_producedStates, name=hits><>Count
#   - pattern: 'net.corda<type=(\w+), component=(\w+), name=(\w+)><>(\w+)(\d+)'
#     name: corda.\$1.\$3
#     value: \$5
#     type: GAUGE
#     attrNameSnakeCase: true
#     labels:
#       type: \$1
#       source: "corda"
#       component: \$2
#       bucket: \$4
#   - pattern: 'net.corda<type=(\w+), name=(\w+)><>(.*): (\d+)'
#     name: corda.\$1.\$2
#     value: \$4
#     type: GAUGE
#     attrNameSnakeCase: true
#     labels:
#       type: \$1
#       source: "corda"
#       bucket: \$3
{}
EOF

printf "Created in: ./mynetwork/shared/drivers/prom_jmx_exporter.yaml\n\n"

# Rebuild the Prometheus configuration
printf "*********************************************************************************\n"
printf "Rebuild the Prometheus configuration\n"
printf "*********************************************************************************\n"

install -m 644 /dev/null ./mynetwork/prometheus/prometheus.yaml
cat <<EOF >./mynetwork/prometheus/prometheus.yaml
global:
  scrape_interval: 10s
  external_labels:
    monitor: "corda-network"
scrape_configs:
  # - job_name: "corda"
  #   static_configs:
  #     - targets: ["notary:8080"]
  #       labels:
  #         role: "group"
  #         role: "notary"
  #     - targets: ["partya:8080", "partyb:8080"]
  #       labels:
  #         role: "group"
  #         role: "participant"
  #   relabel_configs:
  #     - source_labels: [__address__]
  #       regex: "([^:]+):\\\d+"
  #       target_label: node

  - job_name: 'loki'
    static_configs:
    - targets: ['loki:3100']

  - job_name: 'tempo'
    static_configs:
    - targets: ['tempo:3200']

  - job_name: 'otelcollector'
    static_configs:
    - targets: ['otelcollector:9464']
    # relabel_configs:
    #   - source_labels: [__address__]
    #     regex: "([^:]+):\\\d+"
    #     target_label: node
EOF

printf "Created in: ./mynetwork/prometheus/prometheus.yaml\n\n"

# Create Log4j Logging configuration
printf "*********************************************************************************\n"
printf "Create Log4j Logging configuration\n"
printf "*********************************************************************************\n"

install -m 644 /dev/null ./mynetwork/shared/drivers/log4j2.xml
cat <<EOF >./mynetwork/shared/drivers/log4j2.xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
    Corda 4.8 Logging notes @
    https://docs.r3.com/en/platform/corda/4.8/enterprise/node/operating/node-administration.html#logging

    Default logging configuration @
    https://github.com/corda/corda/blob/release/os/4.9/config/dev/log4j2.xml
-->
<Configuration status="WARN" shutdownHook="disable">
    <Appenders>
        <Console name="ConsoleAppender" target="SYSTEM_OUT">
          <!-- <PatternLayout pattern="%d{HH:mm:ss.SSS} [%t] %-5level %logger{36} trace_id: %X{traceId} span_id: %X{spanId} - %msg%n" /> -->
          <PatternLayout>
            <ScriptPatternSelector
                  defaultPattern="%highlight{[%level{length=5}] %date{HH:mm:ssZ} [%t] %c{2}.%method - %msg%n%throwable{0}}{INFO=white,WARN=red,FATAL=bright red}">
              <Script name="MDCSelector" language="javascript">
                <![CDATA[
                  result = null;
                  if (!logEvent.getContextData().size() == 0) {
                      result = "WithMDC";
                  } else {
                      result = null;
                  }
                  result;
                ]]>
              </Script>
              <PatternMatch key="WithMDC" pattern="%highlight{[%level{length=5}] %date{HH:mm:ssZ} [%t] %c{2}.%method - %msg %X%n%throwable{0}}{INFO=white,WARN=red,FATAL=bright red}"/>
            </ScriptPatternSelector>
          </PatternLayout>
        </Console>
        <Console name="ConsoleJSONAppender" target="SYSTEM_OUT">
          <!-- <JsonLayout complete="false" compact="true"/> -->
          <JsonTemplateLayout eventTemplateUri="classpath:LogstashJsonEventLayoutV1.json">
            <EventTemplateAdditionalField key="trace_id" format="JSON"
               value='{"\$resolver": "mdc", "key": "traceId"}'/>
            <EventTemplateAdditionalField key="span_id" format="JSON"
               value='{"\$resolver": "mdc", "key": "spanId"}'/>
          </JsonTemplateLayout>
        </Console>
        <File name="FileAppender" fileName="logs/node-\${env:NODE_NAME}.log">
        <!--
          <PatternLayout>
            <Pattern>%d{HH:mm:ss.SSS} [%t] %-5level %logger{36} trace_id: %X{traceId} span_id: %X{spanId} - %msg%n</Pattern>
          </PatternLayout>
        -->
          <PatternLayout>
            <ScriptPatternSelector defaultPattern="[%-5level] %date{ISO8601}{UTC}Z [%t] %c{2}.%method - %msg%n">
              <Script name="MDCSelector" language="javascript">
                <![CDATA[
                  result = null;
                  if (!logEvent.getContextData().size() == 0) {
                      result = "WithMDC";
                  } else {
                      result = null;
                  }
                  result;
                ]]>
              </Script>
              <PatternMatch key="WithMDC" pattern="[%-5level] %date{ISO8601}{UTC}Z [%t] %c{2}.%method - %msg %X%n"/>
            </ScriptPatternSelector>
          </PatternLayout>
        </File>
        <File name="FileJSONAppender" fileName="logs/node-\${env:NODE_NAME}_json.log">
          <!-- <JsonLayout complete="false" compact="true" properties="true" eventEol="true"/> -->
          <JsonTemplateLayout eventTemplateUri="classpath:LogstashJsonEventLayoutV1.json">
            <EventTemplateAdditionalField key="trace_id" format="JSON"
               value='{"\$resolver": "mdc", "key": "traceId"}'/>
            <EventTemplateAdditionalField key="span_id" format="JSON"
               value='{"\$resolver": "mdc", "key": "spanId"}'/>
          </JsonTemplateLayout>
        </File>
    </Appenders>
    <Loggers>
        <Logger name="BasicInfo" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="net.corda" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="com.r3.corda" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="org.hibernate" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="org.hibernate.SQL" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="org.postgresql" level="info" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="org.apache.activemq.artemis.core.server" level="error" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="org.apache.activemq.audit" level="error" additivity="false">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Logger name="org.jolokia" additivity="true" level="warn">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Logger>
        <Root level="info">
            <AppenderRef ref="FileJSONAppender"/>
            <AppenderRef ref="FileAppender"/>
        </Root>
    </Loggers>
</Configuration>
EOF

printf "Created in: ./mynetwork/shared/drivers/log4j2.xml\n\n"

install -m 644 /dev/null ./mynetwork/shared/drivers/jdk_logging.properties
cat <<EOF >./mynetwork/shared/drivers/jdk_logging.properties
handlers = java.util.logging.FileHandler
.level = INFO

java.util.logging.FileHandler.level     = INFO
java.util.logging.FileHandler.formatter = java.util.logging.SimpleFormatter
java.util.logging.FileHandler.append    = false
java.util.logging.FileHandler.pattern   = logs/log.%u.%g.txt
EOF

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

  # Ref @ https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/simpleprometheusreceiver
  # prometheus_simple/notary:
  #   endpoint: "notary:8080"
  #   tls_enabled: false
  #   collection_interval: 10s

  # Ref @ https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/prometheusreceiver
  prometheus:
    config:
      scrape_configs:
        - job_name: "corda"
          scrape_interval: 5s
          static_configs:
            - targets: ["notary:8080"]
              labels:
                group: "corda"
                role: "notary"
            - targets: ["partya:8080", "partyb:8080"]
              labels:
                group: "corda"
                role: "participant"
          relabel_configs:
            - source_labels: [__address__]
              regex: "([^:]+):\\\d+"
              target_label: node

  filelog/partya:
    include: [ /var/bootstrap/partya/logs/node-partya_json.log ]
    attributes:
      "host.name": partya
  filelog/partyb:
    include: [ /var/bootstrap/partyb/logs/node-partyb_json.log ]
    attributes:
      "host.name": partyb
  filelog/notary:
    include: [ /var/bootstrap/notary/logs/node-notary_json.log ]
    attributes:
      "host.name": notary

processors:
 batch:

extensions:
  health_check:
  pprof:
  zpages:

# https://github.com/grafana/tempo/tree/main/example/docker-compose/otel-collector

exporters:
  otlp:
    # endpoint: tempo:55680   ## DEPRECATED per https://github.com/grafana/tempo/issues/637
    endpoint: tempo:4317
    tls:
      insecure: true
  jaeger:
    endpoint: tempo:14250
    tls:
      insecure: true
#  zipkin:
#    endpoint: "http://zipkin-all-in-one:9411/api/v2/spans"

  # Exposes Prometheus metrics on port 9464.  Configure a job in Prometheus to
  # scrape this target, e.g. http://localhost:9464/metrics
  # See https://alanstorm.com/what-are-open-telemetry-metrics-and-exporters/
  # Ref @ https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusexporter
  prometheus:
    endpoint: "0.0.0.0:9464"

  file:
    path: /tmp/trace.json

  # Export data to Loki 
  # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/lokiexporter
  loki/partya:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      resource:
        # Allowing 'container.name' attribute and transform it to 'container_name', which is a valid Loki label name.
        container.name: "container_name"
        # Transform "host.hostname" within OTEL_RESOURCE_ATTRIBUTES to 'hostname'
        host.hostname: "hostname"
      attributes:
        # Allowing 'severity' attribute and not providing a mapping, since the attribute name is a valid Loki label name.
        severity: ""
        http.status_code: "http_status_code" 
        file.name: "filename"
    headers:
      "X-Custom-Header": "loki_rocks"
  loki/partyb:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      resource:
        container.name: "container_name"
        host.hostname: "hostname"
      attributes:
        severity: ""
        http.status_code: "http_status_code"
        file.name: "filename"
    headers:
      "X-Custom-Header": "loki_rocks"
  loki/notary:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      resource:
        container.name: "container_name"
        host.hostname: "hostname"
      attributes:
        severity: ""
        http.status_code: "http_status_code"
        file.name: "filename"
    headers:
      "X-Custom-Header": "loki_rocks"

service:
  extensions: [pprof, zpages, health_check]
  pipelines:
    traces:
      receivers: [jaeger]
      processors: [batch]
      exporters: [otlp, file]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp, file]
    metrics/corda:
      receivers: [prometheus]
      processors: [batch]
      exporters: [prometheus]
    logs/partya:
      receivers: [ filelog/partya ]
      processors: [batch]
      exporters: [ loki/partya ]
    logs/partyb:
      receivers: [ filelog/partyb ]
      processors: [batch]
      exporters: [ loki/partyb ]
    logs/notary:
      receivers: [ filelog/notary ]
      processors: [batch]
      exporters: [ loki/notary ]
EOF

printf "Created in: ./mynetwork/otelcollector/otel-collector.yaml\n\n"

# Create the Grafana Tempo configuration
printf "*********************************************************************************\n"
printf "Create the Grafana Tempo configuration\n"
printf "*********************************************************************************\n"

install -m 644 /dev/null ./mynetwork/tempo/tempo-local.yaml
cat <<EOF >./mynetwork/tempo/tempo-local.yaml
# Reference @ https://grafana.com/docs/tempo/latest/configuration/

auth_enabled: false

server:
  http_listen_port: 3200

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
      path: /tmp/tempo/wal             # where to store the the wal locally
      #bloom_filter_false_positive: .05 # bloom filter false positive rate.  lower values create larger filters but fewer false positives
      #index_downsample: 10             # number of traces per index record
    local:
      path: /tmp/tempo/blocks
    pool:
      max_workers: 100                 # the worker pool mainly drives querying, but is also used for polling the blocklist
      queue_depth: 10000
EOF

printf "Created in: ./mynetwork/tempo/tempo-local.yaml\n\n"

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
      - ./otelcollector:/tmp
      - ./partya:/var/bootstrap/partya
      - ./partyb:/var/bootstrap/partyb
      - ./notary:/var/bootstrap/notary
    ports:
      ## NOTE: 
      ## Ports 55680/55681 are DEPRECATED per https://github.com/grafana/tempo/issues/637
      - "4317:4317"      # OLTP/gRPC
      - "4318:4318"      # OLTP/http/protobuf
      - "9464:9464"      # OLTP Prometheus exporter /metrics
      - "13133:13133"    # health_check extension
      - "55679:55679"    # zpages extension

    depends_on:
      - notary
      - partya
      - partyb
      - tempo
  #     - jaeger-all-in-one
  #     - zipkin-all-in-one

  # # Jaeger
  # jaeger-all-in-one:
  #   image: jaegertracing/all-in-one:latest
  #   ports:
  #     - "16686:16686"
  #     - "14268"
  #     - "14250"

  # # Zipkin
  # zipkin-all-in-one:
  #   image: openzipkin/zipkin:latest
  #   ports:
  #     - "9411:9411"

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
      - "43170:4317"   # otlp
      - "9411:9411"    # Zipkin
      - "14250:14250"  # Jaeger - model.proto
      - "14268:14268"  # Jaeger ingest, Jaeger - Thrift HTTP
      - "3200:3200"    # tempo

  loki:
    extends:
      file: docker-compose.yml
      service: loki
    environment:
      - JAEGER_AGENT_HOST=tempo
      - JAEGER_ENDPOINT=http://tempo:14268/api/traces      # send traces to Tempo
      - JAEGER_SAMPLER_TYPE=const
      - JAEGER_SAMPLER_PARAM=1

  # OpenTelemetry Java Instrumentation - agent configuration options:
  #   https://github.com/open-telemetry/opentelemetry-java/blob/main/sdk-extensions/autoconfigure/README.md

  notary:
    extends:
      file: docker-compose.yml
      service: notary
    command: bash -c "java -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas --allow-hibernate-to-manage-app-schema && /opt/corda/bin/run-corda"
    environment:
      ## Notice use of JVM_ARGS in https://github.com/corda/corda/blob/release/os/4.9/docker/src/bash/run-corda.sh
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -Djava.util.logging.config.file=/opt/corda/drivers/jdk_logging.properties -Dlog4j.configurationFile=/opt/corda/drivers/log4j2.xml -cp /opt/corda/drivers/opentelemetry-api-1.10.1:/opt/corda/drivers/opentelemetry-sdk-1.10.1.jar:/opt/corda/drivers/opentelemetry-sdk-trace-1.10.1.jar:/opt/corda/drivers/opentelemetry-context-1.10.1.jar:/opt/corda/drivers/opentelemetry-log4j-2.13.2-1.9.2-alpha.jar:/opt/corda/drivers/log4j-layout-template-json-2.17.1.jar -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/prom_jmx_exporter.yaml -javaagent:/opt/corda/drivers/opentelemetry-javaagent.jar"
#      - "CORDA_ARGS=\"--logging-level=INFO\""
      - NODE_NAME=notary
      - OTEL_SERVICE_NAME=corda-notary
      #- OTEL_EXPORTER=otlp_span                            # TODO confirm valid env var
      - OTEL_TRACES_EXPORTER=otlp                          # default is otlp
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otelcollector:4317
      #- OTEL_TRACES_EXPORTER=logging
      #- OTEL_TRACES_EXPORTER=jaeger
      #- OTEL_EXPORTER_JAEGER_ENDPOINT=http://tempo:14250
      - OTEL_RESOURCE_ATTRIBUTES=host.hostname=notary
      #- OTEL_JAVAAGENT_DEBUG=true

  partya:
    extends:
      file: docker-compose.yml
      service: partya
    command: bash -c "java -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas --allow-hibernate-to-manage-app-schema && /opt/corda/bin/run-corda"
    environment:
      ## Notice use of JVM_ARGS in https://github.com/corda/corda/blob/release/os/4.9/docker/src/bash/run-corda.sh
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -Djava.util.logging.config.file=/opt/corda/drivers/jdk_logging.properties -Dlog4j.configurationFile=/opt/corda/drivers/log4j2.xml -cp /opt/corda/drivers/opentelemetry-api-1.10.1:/opt/corda/drivers/opentelemetry-sdk-1.10.1.jar:/opt/corda/drivers/opentelemetry-sdk-trace-1.10.1.jar:/opt/corda/drivers/opentelemetry-context-1.10.1.jar:/opt/corda/drivers/opentelemetry-log4j-2.13.2-1.9.2-alpha.jar:/opt/corda/drivers/log4j-layout-template-json-2.17.1.jar -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/prom_jmx_exporter.yaml -javaagent:/opt/corda/drivers/opentelemetry-javaagent.jar"
#      - "CORDA_ARGS=\"--logging-level=INFO\""
      - NODE_NAME=partya
      - OTEL_SERVICE_NAME=corda-partya
      #- OTEL_EXPORTER=otlp_span                            # TODO confirm valid env var
      - OTEL_TRACES_EXPORTER=otlp                          # default is otlp
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otelcollector:4317
      #- OTEL_TRACES_EXPORTER=logging
      #- OTEL_TRACES_EXPORTER=jaeger
      #- OTEL_EXPORTER_JAEGER_ENDPOINT=http://tempo:14250
      - OTEL_RESOURCE_ATTRIBUTES=host.hostname=partya
      #- OTEL_JAVAAGENT_DEBUG=true

  partyb:
    extends:
      file: docker-compose.yml
      service: partyb
    command: bash -c "java -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas --allow-hibernate-to-manage-app-schema && /opt/corda/bin/run-corda"
    environment:
      ## Notice use of JVM_ARGS in https://github.com/corda/corda/blob/release/os/4.9/docker/src/bash/run-corda.sh
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -Djava.util.logging.config.file=/opt/corda/drivers/jdk_logging.properties -Dlog4j.configurationFile=/opt/corda/drivers/log4j2.xml -cp /opt/corda/drivers/opentelemetry-api-1.10.1:/opt/corda/drivers/opentelemetry-sdk-1.10.1.jar:/opt/corda/drivers/opentelemetry-sdk-trace-1.10.1.jar:/opt/corda/drivers/opentelemetry-context-1.10.1.jar:/opt/corda/drivers/opentelemetry-log4j-2.13.2-1.9.2-alpha.jar:/opt/corda/drivers/log4j-layout-template-json-2.17.1.jar -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/prom_jmx_exporter.yaml -javaagent:/opt/corda/drivers/opentelemetry-javaagent.jar"
#      - "CORDA_ARGS=\"--logging-level=INFO\""
      - NODE_NAME=partyb
      - OTEL_SERVICE_NAME=corda-partyb
      #- OTEL_EXPORTER=otlp_span                            # TODO confirm valid env var
      - OTEL_TRACES_EXPORTER=otlp                          # default is otlp
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otelcollector:4317
      #- OTEL_TRACES_EXPORTER=logging
      #- OTEL_TRACES_EXPORTER=jaeger
      #- OTEL_EXPORTER_JAEGER_ENDPOINT=http://tempo:14250
      - OTEL_RESOURCE_ATTRIBUTES=host.hostname=partyb
      #- OTEL_JAVAAGENT_DEBUG=true
EOF

printf "Created in: ./mynetwork/docker-compose.trace.yml\n"

printf "Run command: docker-compose -f ./mynetwork/docker-compose.trace.yml up -d\n\n"

printf "*********************************************************************************\n"
printf "COMPLETE\n"
printf "*********************************************************************************\n"
