#!/bin/sh -x

base=$(dirname $0)

set +x

units=$(curl -q http://localhost:43273/containers)
ret=$?
if [ $ret -ne 0 ]; then
  echo "gear daemon not responding, make sure the service is running and retry."
  exit 1
fi

units=$(curl -q http://192.168.205.11:43273/containers)
ret=$?
if [ $ret -ne 0 ]; then
  echo "gear daemon on vm2 not responding, make sure the service is running and retry."
  exit 1
fi

$base/teardown-multi.sh

#gear deploy $base/deploy_parks_map.json localhost localhost 192.168.205.11 192.168.205.11 localhost
#gear stop 192.168.205.11/parks-backend-{2,3}

gear install -p "27017:4003" openshift/centos-mongodb --start
gear install -p "3000:4002" -n "127.0.0.1:27017:localhost:4003" parks-map-app parks-backend-1  
gear install -p "8080:14000" -p "192.168.1.1:8080:localhost:4002,129.168.1.2:8080:192.168.205.11:4002,129.168.1.2:8080:192.168.205.11:4003" parks-lb-1
gear install -p "3000:4002" -p "127.0.0.1:27017:192.168.205.10:4003" atomic-2/parks-backend-2
gear install -p "3000:4003" -p "127.0.0.1:27017:192.168.205.10:4003" atomic-2/parks-backend-3

$base/wait_for_url.sh "http://localhost:4003/"

sudo switchns --container=parks-db-1 -- /bin/bash -c "curl https://raw.githubusercontent.com/thesteve0/fluentwebmap/master/parkcoord.json | mongoimport -d fluent -c parkpoints --type json && mongo fluent --eval 'db.parkpoints.ensureIndex( { pos : \"2d\" } );'"
