#!/usr/bin/env bash

# Update node.conf
sed -i '' 's/#//' mynetwork/notary/node.conf
sed -i '' 's/#//' mynetwork/partya/node.conf
sed -i '' 's/#//' mynetwork/partyb/node.conf

# Create Docker-Compose File
printf "*********************************************************************************\n"
printf "Create Docker-Compose File\n"
printf "*********************************************************************************\n"

cat <<EOF >./mynetwork/docker-compose.yml
version: '3.7'

services:
  notarydb:
    image: postgres:latest
    container_name: notarydb
    hostname: notarydb
    environment:
      POSTGRES_PASSWORD: test

  partyadb:
    image: postgres:latest
    container_name: partyadb
    hostname: partyadb
    environment:
      POSTGRES_PASSWORD: test
  
  partybdb:
    image: postgres:latest
    container_name: partybdb
    hostname: partybdb
    environment:
      POSTGRES_PASSWORD: test

  notary:
    image: corda/corda-zulu-java1.8-4.8.6:RELEASE
    container_name: notary
    hostname: notary
    ports:
      - "10002:10201"
    command: bash -c "java -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas && /opt/corda/bin/run-corda"
    volumes:
      - ./notary/node.conf:/etc/corda/node.conf:ro
      - ./notary/certificates:/opt/corda/certificates:ro
      - ./notary/persistence.mv.db:/opt/corda/persistence/persistence.mv.db:rw
      - ./notary/persistence.trace.db:/opt/corda/persistence/persistence.trace.db:rw
      - ./notary/logs:/opt/corda/logs:rw
      - ./shared/additional-node-infos:/opt/corda/additional-node-infos:rw
      - ./shared/drivers:/opt/corda/drivers:ro
      - ./shared/network-parameters:/opt/corda/network-parameters:rw
    environment:
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/prom_jmx_exporter.yaml"
    depends_on:
      - notarydb

  partya:
    image: corda/corda-zulu-java1.8-4.8.6:RELEASE
    container_name: partya
    hostname: partya
    ports:
      - "10005:10201"
      - "2222:2222"
    command: bash -c "java -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas && /opt/corda/bin/run-corda"
    volumes:
      - ./partya/node.conf:/etc/corda/node.conf:ro
      - ./partya/certificates:/opt/corda/certificates:ro
      - ./partya/persistence.mv.db:/opt/corda/persistence/persistence.mv.db:rw
      - ./partya/persistence.trace.db:/opt/corda/persistence/persistence.trace.db:rw
      - ./partya/logs:/opt/corda/logs:rw
      - ./shared/additional-node-infos:/opt/corda/additional-node-infos:rw
      - ./shared/cordapps:/opt/corda/cordapps:rw
      - ./shared/drivers:/opt/corda/drivers:ro
      - ./shared/network-parameters:/opt/corda/network-parameters:rw
    environment:
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/prom_jmx_exporter.yaml"
    depends_on:
      - partyadb

  partyb:
    image: corda/corda-zulu-java1.8-4.8.6:RELEASE
    container_name: partyb
    hostname: partyb
    ports:
      - "10008:10201"
      - "3333:2222"
    command: bash -c "java -jar /opt/corda/bin/corda.jar run-migration-scripts -f /etc/corda/node.conf --core-schemas --app-schemas && /opt/corda/bin/run-corda"
    volumes:
      - ./partyb/node.conf:/etc/corda/node.conf:ro
      - ./partyb/certificates:/opt/corda/certificates:ro
      - ./partyb/persistence.mv.db:/opt/corda/persistence/persistence.mv.db:rw
      - ./partyb/persistence.trace.db:/opt/corda/persistence/persistence.trace.db:rw
      - ./partyb/logs:/opt/corda/logs:rw
      - ./shared/additional-node-infos:/opt/corda/additional-node-infos:rw
      - ./shared/cordapps:/opt/corda/cordapps:rw
      - ./shared/drivers:/opt/corda/drivers:ro
      - ./shared/network-parameters:/opt/corda/network-parameters:rw
    environment:
      - "JVM_ARGS=-XX:+HeapDumpOnOutOfMemoryError -javaagent:/opt/corda/drivers/jmx_prometheus_javaagent-0.16.1.jar=8080:/opt/corda/drivers/prom_jmx_exporter.yaml"
    depends_on:
      - partybdb

  prometheus:
    image: prom/prometheus:v2.33.1
    container_name: prometheus
    hostname: prometheus
    ports:
      - 9090:9090
    command:
      - --config.file=/etc/prometheus/prometheus.yaml
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml:ro

  grafana:
    image: grafana/grafana:8.3.5
    container_name: grafana
    hostname: grafana
    ports:
      - 3000:3000
    volumes:
      - ./grafana:/var/lib/grafana
    environment:
      - "GF_INSTALL_PLUGINS=grafana-clock-panel"
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true

  loki:
    image: grafana/loki:2.4.2
    container_name: loki
    hostname: loki
    ports:
      - "3100:3100"      # loki needs to be exposed so it receives logs
    volumes:
      - ./loki/loki-config.yaml:/etc/loki/local-config.yaml
      - ./loki:/loki
    command: -config.file=/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:2.4.2
    container_name: promtail
    hostname: promtail
    volumes:
      - ./partya/logs:/var/log/partya:ro
      - ./partyb/logs:/var/log/partyb:ro
      - ./notary/logs:/var/log/notary:ro
      - ./promtail/promtail-config.yaml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
EOF

printf "Created in: ./mynetwork/docker-compose.yml\n"

printf "Run command: docker compose -f ./mynetwork/docker-compose.yml up -d\n\n"

printf "*********************************************************************************\n"
printf "COMPLETE\n"
printf "*********************************************************************************\n"