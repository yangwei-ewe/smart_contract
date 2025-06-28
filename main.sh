# !/bin/bash
export FABRIC_CFG_PATH=./config/
export ORDERER_GENERAL_GENESISMETHOD=file
export ORDERER_GENERAL_GENESISFILE=./genesis.block

PORT_ORG1_PEER0_MAIN=7051
PORT_ORG1_PEER0_CHAINCODE=7052
PORT_ORG2_PEER0_MAIN=9051
PORT_ORG2_PEER0_CHAINCODE=8052

org1() {
    export CORE_PEER_LOCALMSPID=Org1MSP
    export CORE_PEER_MSPCONFIGPATH=../organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_GOSSIP_USELEADERELECTION=true
    export CORE_PEER_GOSSIP_ORGLEADER=false
    export CORE_PEER_PROFILE_ENABLED=true
    export CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
    export CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
    export CORE_PEER_TLS_ROOTCERT_FILE=../organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_ID=peer0.org1.example.com
    export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
    export CORE_PEER_CHAINCODEADDRESS=peer0.org1.example.com:7052
    export CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051
    export CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.example.com:7051
    }

org2(){
    export CORE_PEER_LOCALMSPID=Org2MSP
    export CORE_PEER_MSPCONFIGPATH=../organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_GOSSIP_USELEADERELECTION=true
    export CORE_PEER_GOSSIP_ORGLEADER=false
    export CORE_PEER_PROFILE_ENABLED=true
    export CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
    export CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
    export CORE_PEER_TLS_ROOTCERT_FILE=../organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_ID=peer0.org2.example.com
    export CORE_PEER_ADDRESS=peer0.org2.example.com:9051
    export CORE_PEER_CHAINCODEADDRESS=peer0.org2.example.com:7052
    export CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org2.example.com:9051
    export CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org2.example.com:9051
}

refresh() {
    docker compose down
    rm -r organizations channel-artifacts carbonC.tar.gz
    bin/cryptogen generate --config=config/crypto-config.yaml --output organizations 
    bin/configtxgen -profile myFirstGenesis -channelID sys-channel -outputBlock ./channel-artifacts/genesis.block
    bin/configtxgen -profile myFirstChannel -channelID myfirstchannel -outputCreateChannelTx ./channel-artifacts/myfirstchannel.tx
    docker compose up -d
    bin/configtxgen -profile myFirstChannel -channelID myfirstchannel -outputAnchorPeersUpdate ./channel-artifacts/org2anchor.tx -asOrg Org1MSP
    bin/configtxgen -profile myFirstChannel -channelID myfirstchannel -outputAnchorPeersUpdate ./channel-artifacts/org1anchor.tx -channelID myfirstchannel -asOrg Org2MSP
    sleep 1
    bin/peer channel create -o orderer.example.com:7050 -c myfirstchannel -f ./channel-artifacts/myfirstchannel.tx --outputBlock ./channel-artifacts/channel.block --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
    bin/peer lifecycle chaincode package carbonC.tar.gz -p ./chaincode_node_test -l node --label carbon_cc1
}

init() {
    bin/peer channel fetch config config_block.pb -o orderer.example.com:7050 -c myfirstchannel --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
    package_id=$(bin/peer lifecycle chaincode calculatepackageid carbonC.tar.gz)
    echo "get package id: $package_id"
    org1
    bin/peer channel join -b ./channel-artifacts/channel.block
  #   bin/peer channel update -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com \
  # -c myfirstchannel \
  # -f ./channel-artifacts/org1anchor.tx \
  # --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
    bin/peer lifecycle chaincode install carbonC.tar.gz --tls --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    echo "channel list:"
    bin/peer channel list
    echo "queryinstalled on org1:"
    bin/peer lifecycle chaincode queryinstalled
    bin/peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --channelID myfirstchannel --name carbon_cc1 --package-id $package_id --version 0.1 --sequence 1
    bin/peer lifecycle chaincode queryapproved -C myfirstchannel -n carbon_cc1 --tls

    org2
    bin/peer channel join -b ./channel-artifacts/channel.block
  #   bin/peer channel update -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com \
  # -c myfirstchannel \
  # -f ./channel-artifacts/org2anchor.tx \
  # --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt

    bin/peer channel list
    bin/peer lifecycle chaincode install carbonC.tar.gz --tls --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org2.example.com/tls/ca.crt
    echo "queryinstalled on org2:"
    bin/peer lifecycle chaincode queryinstalled
    bin/peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --channelID myfirstchannel --name carbon_cc1 --package-id $package_id --version 0.1 --sequence 1
    bin/peer lifecycle chaincode queryapproved -C myfirstchannel -n carbon_cc1 --tls
    org1
    bin/peer lifecycle chaincode checkcommitreadiness -C myfirstchannel -n carbon_cc1 -v 0.1 --sequence 1 --tls 
    bin/peer lifecycle chaincode commit --channelID myfirstchannel --name carbon_cc1 --version 0.1 --sequence 1 -o orderer.example.com:7050 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    bin/peer lifecycle chaincode querycommitted -C myfirstchannel -n carbon_cc1 --tls --output json
    echo "init completed."
}

org1
refresh
init
org1


echo "init: "
bin/peer chaincode invoke -C myfirstchannel -n carbon_cc1 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"Args":["initLedger"]}'
sleep 1

# read _ -p "Press an key to start"
echo "issueCredit: "
bin/peer chaincode invoke -C myfirstchannel -n carbon_cc1 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"Args":["issueCredit", "CREDIT2", "org2", "200"]}'
sleep 1

echo "readCredit: "
bin/peer chaincode invoke -C myfirstchannel -n carbon_cc1 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"Args":["readCredit", "CREDIT0"]}'
sleep 1

echo "getBalance: "
bin/peer chaincode query -C myfirstchannel -n carbon_cc1 -c '{"Args":["getBalance", "org2"]}' --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
sleep 1

# read -p "Press any key to continue" _
echo "balance of org1 before transfer: "
bin/peer chaincode invoke -C myfirstchannel -n carbon_cc1 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"Args":["getBalance", "org1"]}'
sleep 1

echo "transfer: "
bin/peer chaincode invoke -C myfirstchannel -n carbon_cc1 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"Args":["transferCredit", "CREDIT2", "org1"]}'
sleep 1

echo "balance of org1 after transfer: "
bin/peer chaincode invoke -C myfirstchannel -n carbon_cc1 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"Args":["getBalance", "org1"]}'
sleep 2

# echo "snapshot: "
# bin/peer chaincode invoke -C myfirstchannel -n carbon_cc1 --tls --cafile ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"Args":["snapshotLedger"]}'
