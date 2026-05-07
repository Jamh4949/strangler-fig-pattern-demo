#!/usr/bin/env bash

set -euo pipefail

MONGODB_HOST="mongodb:27017"
MAX_RETRIES=60

echo "********************************************** ${MONGODB_HOST}"
echo "Waiting for MongoDB to accept connections..."

until mongo --host "${MONGODB_HOST}" --quiet --eval 'db.adminCommand({ ping: 1 })' >/dev/null 2>&1; do
  sleep 2
done

echo "done"
echo "SETUP.sh time now: $(date +%T)"

echo "Checking replica set state..."

mongo --host "${MONGODB_HOST}" --quiet --eval '
const status = rs.status();

if (status.ok === 1) {
    print("Replica set already initialized, state=" + status.myState);
} else if (status.code === 94 || status.codeName === "NotYetInitialized") {
    print("Replica set not initialized. Running rs.initiate...");
    const initResult = rs.initiate({_id: "rs0", members: [{_id: 0, host: "mongodb:27017"}]});
    printjson(initResult);
} else {
    printjson(status);
    quit(1);
}
'

echo "Waiting for PRIMARY state..."
for i in $(seq 1 ${MAX_RETRIES}); do
    if mongo --host "${MONGODB_HOST}" --quiet --eval 'db.isMaster().ismaster' | grep -q true; then
        echo "Replica set is PRIMARY. Setup complete."
        mongo --host "${MONGODB_HOST}" --quiet --eval 'printjson(rs.status())'
        exit 0
    fi
    sleep 2
done

echo "Replica set did not become PRIMARY in time."
exit 1
