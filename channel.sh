#!/bin/bash
for (( i=0; i<320; i++ ))
do
    ./configtxgen -profile multihostChannel -outputCreateChannelTx ./channels/myc$i.tx -channelID myc$i
done
