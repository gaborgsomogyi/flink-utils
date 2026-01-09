# Flink Utilities

* `verify-flink-release/flink.sh`: This script tries to automate steps of the [verification process](https://cwiki.apache.org/confluence/display/FLINK/Verifying+a+Flink+Release) within Apache Flink. Run `./verify-flink-release/flink.sh` to get further details on how to use the script.
* `verify-flink-release/flink-shaded.sh`: Similar script to check [flink-shaded|https://github.com/apache/flink-shaded] releases
* `verify-flink-release/flink-connector.sh`: Similar script to check Flink connector releases

## Usage

### Flink Core
```
GPG_KEY=XXX
gpg --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEY}
FLINK_VERSION=2.0.1-rc1
MVN_CMD=${HOME}/flink/mvnw
WORK_DIR=${HOME}/flink-validate
rm -rf ${WORK_DIR}/*

./verify-flink-release/flink.sh -u https://dist.apache.org/repos/dist/dev/flink/flink-${FLINK_VERSION} -g ${GPG_KEY} -b ${FLINK_VERSION} -m ${MVN_CMD} -w ${WORK_DIR}
```

### Flink Connectors
```
GPG_KEY=XXX
gpg --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEY}
CONNECTOR_NAME=flink-connector-aws
CONNECTOR_VERSION=5.1.0
TARGET_TAG=v${CONNECTOR_VERSION}-rc2
BASE_TAG=v5.0.0
MVN_CMD=${HOME}/flink/mvnw
WORK_DIR=${HOME}/flink-validate
rm -rf ${WORK_DIR}/*

./verify-flink-release/flink-connector.sh -u https://dist.apache.org/repos/dist/dev/flink/${CONNECTOR_NAME}-${CONNECTOR_VERSION}-rc2 -g ${GPG_KEY} -t ${TARGET_TAG} -b ${BASE_TAG} -m ${MVN_CMD} -w ${WORK_DIR}
```
