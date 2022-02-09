# Corda Observability with OpenTelemetry, Prometheus, Grafana and Loki
This project demonstrates how to build a robust observability architecture encompassing metrics, logs, and tracing for a Corda environment.  The ability to measure the [Four Golden Signals of Observability](https://sre.google/sre-book/monitoring-distributed-systems/) allows us to be proactive in responding to system misbehaviors.

The architecture is built on some of the most popular open source projects today including:
| Component | Version |
| --- | --- |
| OpenTelemetry Instrumentation for Java | [1.10](https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases) |
| Prometheus JMX exporter | [0.16.1](https://github.com/prometheus/jmx_exporter/releases) |
| Prometheus | [2.33.1](https://github.com/prometheus/prometheus/releases) |
| Grafana Loki and Promtail | [2.4.2](https://github.com/grafana/loki/releases) |
| Grafana | [8.3.5](https://grafana.com/grafana/download) |

- [Step 01: Prepare the workspace directory](#step-1-prepare-the-workspace-directory)
- [Step 02: Create node configuration files](#step-2-create-node-configuration-files)
- [Step 03: Run the Corda Network Bootstrapper](#step-3-run-the-corda-network-bootstrapper)
- [Step 04: Preparing for Docker](#step-4-preparing-for-docker)
- [Step 05: Create the Prometheus configuration files](#step-5-create-the-prometheus-configuration-files)
- [Step 06: Create the Docker-Compose file](#step-6-create-the-docker-compose-file)
- [Step 07: Add Trace components](#step-7-add-trace-components)
- [Step 08: Setup Grafana](#step-8-setup-grafana)
- [Step 09: Explore Grafana](#step-9-explore-grafana)
- [Step 10: Run some Corda Finance flows](#step-10-run-some-corda-finance-flows)
- [Common issues](#common-issues)
  - [Docker Desktop OOM](#docker-desktop-oom)
- [Attribution](#attribution)

## Step 1: Prepare the workspace directory

We will create the directory structure and download the necessary from [R3's Artifactory](https://software.r3.com/artifactory/corda-releases/net/corda/):

- corda-tools-network-bootstrapper-4.8.6.jar
- corda-finance-contracts-4.8.6.jar
- corda-finance-workflows-4.8.6.jar

The two `corda-finance-*.jar`'s make up the Corda Finance CordApp which we will use to test transactions across peer nodes.

Execute the **`01_setup-directory.sh`** shell script:

```bash
./01_setup-directory.sh
```

You should see a new directory called `mynetwork` created, with a few sub directories and the required jars.

```bash
➜  tree mynetwork
mynetwork
├── corda-tools-network-bootstrapper-4.8.6.jar
├── grafana
├── loki
├── prometheus
├── promtail
└── shared
    ├── additional-node-infos
    └── cordapps
        ├── corda-finance-contracts-4.8.6.jar
        └── corda-finance-workflows-4.8.6.jar
    └── drivers
        ├── jmx_prometheus_javaagent-0.16.1.jar
        └── postgresql-42.3.1.jar
```

## Step 2: Create node configuration files

We will require 4 node configurations:

- Notary
- PartyA
- PartyB

Execute the **`02_create-node-configurations.sh`** shell script:

```bash
./02_create-node-configurations.sh
```

Our `mynetwork` directory now looks like the following:

```bash
➜  tree mynetwork
mynetwork
├── corda-tools-network-bootstrapper-4.8.6.jar
├── grafana
├── loki
├── notary_node.conf
├── partya_node.conf
├── partyb_node.conf
├── prometheus
├── promtail
└── shared
    ├── additional-node-infos
    └── cordapps
        ├── corda-finance-contracts-4.8.6.jar
        └── corda-finance-workflows-4.8.6.jar
    └── drivers
        ├── jmx_prometheus_javaagent-0.16.1.jar
        └── postgresql-42.3.1.jar
```

This will create three `.conf` files, each representing a single node.

Here's an example of the `partya_node.conf` file:

```conf
devMode=true
emailAddress="test@test.com"
myLegalName="O=PartyA, L=London, C=GB"
p2pAddress="partya:10200"
rpcSettings {
    address="0.0.0.0:10201"
    adminAddress="0.0.0.0:10202"
}
security {
    authService {
        dataSource {
            type=INMEMORY
            users=[
                {
                    password="password"
                    permissions=[
                        ALL
                    ]
                    username=user
                }
            ]
        }
    }
}
cordappSignerKeyFingerprintBlacklist = []
sshd {
  port = 2222
}
```

## Step 3: Run the Corda Network Bootstrapper

The [Corda Network Bootstrapper](https://docs.corda.net/docs/corda-os/4.8/network-bootstrapper.html#bootstrapping-a-test-network) will create a development network of peer nodes, using dev certificates.  You don't need to worry about registering nodes, the bootstrapper takes care of that for you.

Execute the **`03_run-corda-network-bootstrapper.sh`** shell script:

```bash
./03_run-corda-network-bootstrapper.sh
```
```
Bootstrapping local test network in /corda-observability/mynetwork
Generating node directory for partya
Generating node directory for notary
Generating node directory for partyb
Nodes found in the following sub-directories: [notary, partya, partyb]
Found the following CorDapps: [corda-finance-workflows-4.8.6.jar, corda-finance-contracts-4.8.6.jar]
Copying CorDapp JARs into node directories
Waiting for all nodes to generate their node-info files...
Distributing all node-info files to all nodes
Loading existing network parameters... none found
Gathering notary identities
Generating contract implementations whitelist
New NetworkParameters {
      minimumPlatformVersion=10
      notaries=[NotaryInfo(identity=O=Notary, L=London, C=GB, validating=false)]
      maxMessageSize=10485760
      maxTransactionSize=524288000
      whitelistedContractImplementations {

      }
      eventHorizon=PT720H
      packageOwnership {

      }
      modifiedTime=2022-01-15T22:04:25.555Z
      epoch=1
  }
Bootstrapping complete!
```

## Step 4: Preparing for Docker

There are some common files that are shared between the peer nodes.  Let's put these in one folder - this will make our Docker-Compose service volumes a bit clearer to read.

Execute the **`04_copy-common-files.sh`** shell script:

```bash
./04_copy-common-files.sh
```

This will copy across common files to the `./mynetwork/shared` folder.

## Step 5: Create the Prometheus configuration files

Execute the **`05_create-monitoring-configurations.sh`** shell script:

```bash
./05_create-monitoring-configurations.sh
```

This creates a config file in `./mynetwork/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 5s
  external_labels:
    monitor: "corda-network"
scrape_configs:
  - job_name: "notary"
    static_configs:
      - targets: ["notary:8080"]
    relabel_configs:
      - source_labels: [__address__]
        regex: "([^:]+):\\d+"
        target_label: instance
  - job_name: "nodes"
    static_configs:
      - targets: ["partya:8080", "partyb:8080"]
    relabel_configs:
      - source_labels: [__address__]
        regex: "([^:]+):\\d+"
        target_label: instance
```

Check out the `./mynetwork/promtail/` and `./mynetwork/loki/` directories for their respective configuration files.

We define the JMX exporter targets (endpoints) for each node.  They are all using port 8080 - don't worry about port conflicts, Docker will take care of the networking.

## Step 6: Create the Docker-Compose file

We need a `docker-compose.yml` file which allows us to bring up all the services in just one command.

Execute the **`06_create-docker-compose-file.sh`** shell script:

```bash
./06_create-docker-compose.sh
```

You can find the `docker-compose.yml` file in `./mynetwork/docker-compose.yml`. Inside the file, you have created services for each node database, along with Prometheus, Grafana, Promtail and Loki:

```yaml
...
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - 9090:9090
    command:
      - --config.file=/etc/prometheus/prometheus.yml
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro

  grafana:
    image: grafana/grafana:latest
    hostname: grafana
    container_name: grafana
    ports:
      - 3000:3000
    volumes:
      - ./grafana/data:/var/lib/grafana
    environment:
      - "GF_INSTALL_PLUGINS=grafana-clock-panel"

  loki:
    image: grafana/loki:2.4.2
    container_name: loki
    hostname: loki
    ports:
      - "3100:3100"
    volumes:
     - ./loki/loki-config.yaml:/etc/loki/local-config.yaml
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
  
```
The stack you have configured so far looks like this:
![Deployment Stack 1](/assets/demo_stack_1.png)

At this point, you have two options:
* Complete the rest of this step to instantiate your stack and then start [setting up your Grafana dashboard](#step-8-setup-grafana).  
    -OR-
* Jump to the next step (i.e. NOT completing this step) to [add trace components to your stack](#step-7-add-trace-components).

Start up the services using the following command:

```bash
➜ docker compose -f ./mynetwork/docker-compose.yml up -d
[+] Running 10/10
 ⠿ Network mynetwork_default  Created
 ⠿ Container prometheus  Started                12.5s
 ⠿ Container notarydb    Started                12.2s
 ⠿ Container grafana     Started                12.4s
 ⠿ Container promtail    Started                12.5s
 ⠿ Container partybdb    Started                12.2s
 ⠿ Container partyadb    Started                12.2s
 ⠿ Container loki        Started                12.4s
 ⠿ Container partya      Started                12.9s
 ⠿ Container notary      Started                12.6s
 ⠿ Container partyb      Started                12.6s
```

View running containers:

```bash
==> docker ps -a
CONTAINER ID   IMAGE                                    COMMAND                  CREATED              STATUS              PORTS                                                                    NAMES
c4b67d8e786a   corda/corda-zulu-java1.8-4.8.6:RELEASE   "bash -c 'java -jar …"   About a minute ago   Up About a minute   10200/tcp, 10202/tcp, 0.0.0.0:10002->10201/tcp                           notary
2e64af7ceab5   corda/corda-zulu-java1.8-4.8.6:RELEASE   "bash -c 'java -jar …"   About a minute ago   Up About a minute   10200/tcp, 10202/tcp, 0.0.0.0:3333->2222/tcp, 0.0.0.0:10008->10201/tcp   partyb
6da0d4dfe6fe   corda/corda-zulu-java1.8-4.8.6:RELEASE   "bash -c 'java -jar …"   About a minute ago   Up About a minute   10200/tcp, 0.0.0.0:2222->2222/tcp, 10202/tcp, 0.0.0.0:10005->10201/tcp   partya
1ba72c28f0b5   postgres:latest                          "docker-entrypoint.s…"   About a minute ago   Up About a minute   5432/tcp                                                                 notarydb
328b3c7d8fd1   grafana/loki:2.4.2                       "/usr/bin/loki -conf…"   About a minute ago   Up About a minute   0.0.0.0:3100->3100/tcp                                                   loki
86d80c570772   prom/prometheus:latest                   "/bin/prometheus --c…"   About a minute ago   Up About a minute   0.0.0.0:9090->9090/tcp                                                   prometheus
b215cabeb5a9   postgres:latest                          "docker-entrypoint.s…"   About a minute ago   Up About a minute   5432/tcp                                                                 partybdb
31228df83a18   postgres:latest                          "docker-entrypoint.s…"   About a minute ago   Up About a minute   5432/tcp                                                                 partyadb
dc43c05edd0e   grafana/grafana:latest                   "/run.sh"                About a minute ago   Up About a minute   0.0.0.0:3000->3000/tcp                                                   grafana
4615072d52fd   grafana/promtail:2.4.2                   "/usr/bin/promtail -…"   About a minute ago   Up About a minute                                                                            promtail
```

## Step 7: Add Trace Components

Execute the **`07_add-trace.sh`** shell script:

```bash
./07_add-trace.sh
```

Start up the services using the following command:
```bash
docker compose -f mynetwork/docker-compose.yml -f mynetwork/docker-compose.trace.yml up -d
```

```bash
➜ docker compose -f mynetwork/docker-compose.yml -f mynetwork/docker-compose.trace.yml up -d
[+] Running 13/13
 ⠿ Network mynetwork_default  Created
 ⠿ Container prometheus    Started                12.5s
 ⠿ Container notarydb      Started                12.2s
 ⠿ Container grafana       Started                12.4s
 ⠿ Container otelcollector Started                12.1s
 ⠿ Container tempo         Started                12.3s
 ⠿ Container promtail      Started                12.5s
 ⠿ Container partybdb      Started                12.2s
 ⠿ Container partyadb      Started                12.2s
 ⠿ Container loki          Started                12.4s
 ⠿ Container partya        Started                12.9s
 ⠿ Container notary        Started                12.6s
 ⠿ Container partyb        Started                12.6s
```
The stack you now have looks like this:
![Deployment Stack 2](/assets/demo_stack_2.png)

## Step 8: Setup Grafana

On your browser, go to [http://localhost:3000](http://localhost:3000).

![Grafana homepage](/assets/grafana-homepage.png)

## Step 8.1: Add Prometheus Data Source
Click on `Add data source`.

Select the `Prometheus` data source under `Time series databases`.

Under `HTTP`, set the `URL` to `http://prometheus:9090`.  You can use the Prometheus Docker container hostname here as all of the containers run on the same Docker bridge network, so no explicit container IP addresses need to be used for connectivity.

![Grafana Prometheus data source](/assets/grafana-prometheus-datasource.png)

At the bottom of the page, click on `Save & Test`.  You should see a green alert - `Data source is working`.

Hover over the `Dashboards` icon, and click `Manage`.

Click `Import`, then `Upload .json file`, and navigate to the clone repository folder.  Inside the `grafana` folder, you will see a json file - `Grafana-Corda-Network-Overview.json`, see [here](./grafana/Grafana-Corda-Network-Overview.json).

On the following screen, click `Import`.

Boom, a dashboard appears!

![Grafana Corda dashboard](/assets/grafana-corda-dashboard.png)

## Step 8.2: Add Loki Data Source
Add the Loki data source under Logging & document databases.
![Grafana Loki Data Source](/assets/grafana-loki-datasource.png)

Under `HTTP`, set the `URL` to `http://loki:3100`.
At the bottom of the page, click on Save & Test. You should see a green alert - `Data source is working`.

## Step 9: Explore Grafana

Go back to your [Grafana dashboard](http://localhost:3000).  In the Grafana side pane, click on `Explore`.
At the top you will see a dropdown with data sources you can select — select the `Loki` data source.
Click `Split` on the top right menu pane.

## Step 10: Run some Corda Finance flows

SSH into the PartyA node Crash shell:

```bash
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no user@localhost -p 2222
```

When prompted, the password is `password`.

You should see the following in your terminal:

```bash
Welcome to the Corda interactive shell.
You can see the available commands by typing 'help'.

Mon Jun 15 07:52:13 GMT 2020>>>
```

Let's execute a `CashIssueAndPaymentFlow`:
```bash
flow start CashIssueAndPaymentFlow amount: 1000 GBP, issueRef: TestTransaction, recipient: PartyB, anonymous: false, notary: Notary
```

```bash
Mon Jun 15 07:53:52 GMT 2020>>> flow start CashIssueAndPaymentFlow amount: 1000 GBP, issueRef: TestTransaction, recipient: PartyB, anonymous: false, notary: Notary

 ✓ Starting
 ✓ Issuing cash
          Generating anonymous identities
     ✓ Generating transaction
     ✓ Signing transaction
     ✓ Finalising transaction
              Requesting signature by notary service
                  Requesting signature by Notary service
                  Validating response from Notary service
         ✓ Broadcasting transaction to participants
 ✓ Paying recipient
     ✓ Generating anonymous identities
     ✓ Generating transaction
     ✓ Signing transaction
     ✓ Finalising transaction
         ✓ Requesting signature by notary service
             ✓ Requesting signature by Notary service
             ✓ Validating response from Notary service
         ✓ Broadcasting transaction to participants
▶︎ Done
Flow completed with result: Result(stx=SignedTransaction(id=FB08662B2E0A19ECF9B0E3E44D2DF25934F9576DBF262D794EE2C795C3269503), recipient=O=PartyB, L=London, C=GB)
```

![Grafana Corda dashboard after transaction](/assets/grafana-corda-dashboard-tx.png)

## Common issues

### Docker Desktop OOM

If your containers are exiting with code 137, this is a Docker out-of-memory (OOM) exception.

Go to **Docker Desktop** -> **Preferences** -> **Resources**.  Increase the `Memory` to 10.00 GB, then **Apply & Restart**.

## Attribution

Credits to Neal Shah for sharing his original work @ https://github.com/neal-shah/corda-monitoring-prometheus-grafana-loki.

