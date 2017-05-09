#!/bin/bash

#Node names and IP addresses of the hosts to be used
ZK_NODE="manager" # Node name of the host where zookeeper to be launched
ZK_IP="9.37.192.36" #Ip address of the host where zookeeper is running
KAFKA_NODE="manager" #Node name of the host where kafka to be launched
ORDERER_NODE="manager" #Node name of the host where orderer to be launched
PEER_NODE1="fabric06"
PEER_IP1="9.37.138.34"
PEER_NODE2="fabric07"
PEER_IP2="9.37.138.38"
PEER_NODE3="fabric08"
PEER_IP3="9.42.21.199"
PEER_NODE4="fabric09"
PEER_IP4="9.42.21.226"







function printHelp {

   echo "Usage: "
   echo " ./multihost_latest_launcher.sh [opt] [value] "
   echo "    -z: number of zookeepers, default=1"
   echo "    -k: number of kafka, default=5"
   echo "    -o: number of orderers, default=4"
   echo "    -r: number of organizations, default=2"
   echo "    -c: channel name, default=myc0"
   echo " "
   echo " example: "
   echo " ./multihost_latest_launcher.sh -z 1 -k 5 -o 4 -r 2 -c myc0"
   exit
}

#defaults
nZookeeper=1
nKafka=5
nOrderer=4
nOrgs=2
channel="myc0"


while getopts ":z:k:o:r:c:" opt; 
do
	case $opt in
        	z)
	  	  nZookeeper=$OPTARG
        	;;
        	k)
          	  nKafka=$OPTARG
        	;;
        	o)
          	  nOrderer=$OPTARG
        	;;
        	r)
          	  nOrgs=$OPTARG
        	;;
        	c)
          	  channel=$OPTARG
        	;;
        	\?)
      		   echo "Invalid option: -$OPTARG" >&2
      		   printHelp
      		;;
    		:)
      		  echo "Option -$OPTARG requires an argument." >&2
          	  printHelp
      		;;
   	esac
done

echo "Launching zookeepers"
for (( i=0; i<$nZookeeper; i++ ))
do
	docker service create --name zookeeper$i \
	--network my-network \
	--restart-condition none \
	--constraint 'node.hostname == '$ZK_NODE \
	--publish 2181:2181 \
	rameshthoomu/fabric-zookeeper-x86_64:x86_64-1.0.0-snapshot-2df18bf
done

echo "Launching kafka brokers"
for (( i=0, j=9092 ; i<$nKafka; i++, j++ ))
do
	docker service create --name kafka$i \
	--network my-network \
	--restart-condition none \
	--constraint 'node.hostname == '$KAFKA_NODE \
	--env KAFKA_BROKER_ID=$i \
	--env KAFKA_MESSAGE_MAX_BYTES=103809024 \
	--env KAFKA_REPLICA_FETCH_MAX_BYTES=103809024 \
	--env KAFKA_NUM_REPLICA_FETCHERS=$nKafka \
	--env KAFKA_ZOOKEEPER_CONNECT=$ZK_IP:2181 \
	--env KAFKA_DEFAULT_REPLICATION_FACTOR=$nKafka \
	--env KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE=false \
	--publish $j:9092 \
	rameshthoomu/fabric-kafka-x86_64:x86_64-1.0.0-snapshot-2df18bf
done

sleep 10

echo "Launching Orderers"
for (( i=0, j=7050 ; i<$nOrderer ; i++, j=j+20 ))
do 
	docker service create --name orderer$i \
	--network my-network  \
	--restart-condition none \
	--constraint 'node.hostname == '$ORDERER_NODE \
        --hostname orderer`expr $i + 1`.example.com \
	--env ORDERER_GENERAL_LOGLEVEL=debug \
	--env ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
	--env ORDERER_GENERAL_GENESISMETHOD=file \
	--env ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.block \
	--env ORDERER_GENERAL_LOCALMSPID=OrdererMSP \
	--env ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp  \
        --env ORDERER_GENERAL_TLS_ENABLED=true \
        --env ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key \
        --env ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt \
        --env ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt] \
	--workdir /opt/gopath/src/github.com/hyperledger/fabric  \
	--mount type=bind,src=/home/ibmadmin/multihost_latest/channels/orderer.block,dst=/var/hyperledger/orderer/orderer.block  \
	--mount type=bind,src=/home/ibmadmin/multihost_latest/crypto-config/ordererOrganizations/example.com/orderers/orderer`expr $i + 1`.example.com/msp,dst=/var/hyperledger/orderer/msp \
        --mount type=bind,src=/home/ibmadmin/multihost_latest/crypto-config/ordererOrganizations/example.com/orderers/orderer`expr $i + 1`.example.com/tls,dst=/var/hyperledger/orderer/tls \
	--publish $j:7050 \
	rameshthoomu/fabric-orderer-x86_64:x86_64-1.0.0-snapshot-2df18bf orderer
done

echo "Launching Peers"
total_orgs=$nOrgs
for (( i=1, port1=7051, port2=7061 ; i<=$total_orgs ; i++, port1=port1+20, port2=port2+20 )) 
do
        tmp=$((i % 2))
        case $tmp in 
             1) hostname1=$PEER_NODE1 ; ip1=$PEER_IP1 ; hostname2=$PEER_NODE2 ; ip2=$PEER_IP2 ;;
             0) hostname1=$PEER_NODE3 ; ip1=$PEER_IP3 ; hostname2=$PEER_NODE4 ; ip2=$PEER_IP4 ;;
        esac
	echo "Launching org${i}-peer0"
	docker service create --name org${i}-peer0 \
	--network my-network \
	--restart-condition none \
	--constraint 'node.hostname == '$hostname1 \
	--env CORE_PEER_ADDRESSAUTODETECT=false \
	--env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
	--env CORE_LOGGING_LEVEL=DEBUG \
	--env CORE_PEER_ENDORSER_ENABLED=true \
	--env CORE_PEER_GOSSIP_ORGLEADER=false \
	--env CORE_PEER_GOSSIP_USELEADERELECTION=true \
	--env CORE_PEER_PROFILE_ENABLED=true \
	--env CORE_PEER_ADDRESS=$ip1:$port1 \
	--env CORE_PEER_ID=org${i}-peer0 \
	--env CORE_PEER_LOCALMSPID=Org${i}MSP \
	--env CORE_PEER_GOSSIP_EXTERNALENDPOINT=$ip1:$port1 \
        --env CORE_PEER_TLS_ENABLED=true \
      	--env CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
      	--env CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
      	--env CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
        --env CORE_PEER_TLS_SERVERHOSTOVERRIDE=peer0.org$i.example.com \
	--workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
	--mount type=bind,src=/var/run/,dst=/host/var/run/ \
	--mount type=bind,src=/home/ibmadmin/multihost_latest/crypto-config/peerOrganizations/org$i.example.com/peers/peer0.org$i.example.com/msp,dst=/etc/hyperledger/fabric/msp \
        --mount type=bind,src=/home/ibmadmin/multihost_latest/crypto-config/peerOrganizations/org$i.example.com/peers/peer0.org$i.example.com/tls,dst=/etc/hyperledger/fabric/tls \
	--publish $port1:7051 \
	--publish `expr $port1 + 2`:7053 \
	rameshthoomu/fabric-peer-x86_64:x86_64-1.0.0-snapshot-2df18bf peer node start --peer-defaultchain=false
        	
	echo "Launching org${i}-peer1"
	docker service create --name org${i}-peer1 \
       	--network my-network \
       	--restart-condition none \
       	--constraint 'node.hostname == '$hostname2 \
       	--env CORE_PEER_ADDRESSAUTODETECT=false \
       	--env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
       	--env CORE_LOGGING_LEVEL=DEBUG \
       	--env CORE_PEER_ENDORSER_ENABLED=true \
       	--env CORE_PEER_GOSSIP_ORGLEADER=false \
       	--env CORE_PEER_GOSSIP_USELEADERELECTION=true \
       	--env CORE_PEER_PROFILE_ENABLED=true \
       	--env CORE_PEER_ADDRESS=$hostname2:$port2 \
       	--env CORE_PEER_ID=org${i}-peer1 \
       	--env CORE_PEER_LOCALMSPID=Org${i}MSP \
       	--env CORE_PEER_GOSSIP_BOOTSTRAP=$ip1:$port1 \
        --env CORE_PEER_TLS_ENABLED=true \
        --env CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
        --env CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
        --env CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
        --env CORE_PEER_TLS_SERVERHOSTOVERRIDE=peer1.org$i.example.com \
       	--workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
       	--mount type=bind,src=/var/run/,dst=/host/var/run/ \
       	--mount type=bind,src=/home/ibmadmin/multihost_latest/crypto-config/peerOrganizations/org$i.example.com/peers/peer1.org$i.example.com/msp,dst=/etc/hyperledger/fabric/msp \
        --mount type=bind,src=/home/ibmadmin/multihost_latest/crypto-config/peerOrganizations/org$i.example.com/peers/peer1.org$i.example.com/tls,dst=/etc/hyperledger/fabric/tls \
       	--publish $port2:7051 \
       	--publish `expr $port2 + 2`:7053 \
       	rameshthoomu/fabric-peer-x86_64:x86_64-1.0.0-snapshot-2df18bf peer node start --peer-defaultchain=false
        
done
sleep 15
echo "Launching CLI"
docker service create --name cli \
--tty=true \
--network my-network \
--restart-condition none \
--constraint 'node.hostname == peermanager' \
--env GOPATH=/opt/gopath \
--env CORE_PEER_ADDRESSAUTODETECT=false \
--env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
--env CORE_LOGGING_LEVEL=DEBUG \
--env CORE_PEER_ID=cli \
--env CORE_PEER_ADDRESS=9.37.138.34:7051 \
--env CORE_PEER_LOCALMSPID=Org1MSP \
--env CORE_PEER_TLS_ENABLED=true \
--env CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt \
--env CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key \
--env CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
--env CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
--env CORE_PEER_TLS_SERVERHOSTOVERRIDE=peer0.org1.example.com \
--workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
--mount type=bind,src=/var/run,dst=/host/var/run \
--mount type=bind,src=/home/ibmadmin/multihost_latest/crypto-config,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto \
--mount type=bind,src=/home/ibmadmin/multihost_latest/channels,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/channels \
--mount type=bind,src=/home/ibmadmin/multihost_latest/scripts,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts \
--mount type=bind,src=/home/ibmadmin/multihost_latest/chaincodes,dst=/opt/gopath/src/github.com/hyperledger/fabric/examples/chaincode \
rameshthoomu/fabric-peer-x86_64:x86_64-1.0.0-snapshot-2df18bf  /bin/bash -c './scripts/script.sh '$channel'; '
