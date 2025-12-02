# Flink Utilities

* `verify-flink-release/flink.sh`: This script tries to automate steps of the [verification process](https://cwiki.apache.org/confluence/display/FLINK/Verifying+a+Flink+Release) within Apache Flink. Run `./verify-flink-release/flink.sh` to get further details on how to use the script.
* `verify-flink-release/flink-shaded.sh`: Similar script to check [flink-shaded|https://github.com/apache/flink-shaded] releases

## Usage
```
GPG_KEY=XXX
gpg --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEY}
FLINK_VERSION=2.0.1-rc1
MVN_CMD=${HOME}/flink/mvnw
WORK_DIR=${HOME}/flink-validate
rm -rf ${WORK_DIR}/*

./verify-flink-release/flink.sh -u https://dist.apache.org/repos/dist/dev/flink/flink-${FLINK_VERSION} -g ${GPG_KEY} -b ${FLINK_VERSION} -m ${MVN_CMD} -w ${WORK_DIR}
```
