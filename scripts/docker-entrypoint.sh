#!/bin/bash
set -e

cd /app

# Only local runtime dir needed — all table data lives on s3a://warehouse/.
mkdir -p .tmp/spark-events logs

MODE="${1:-connect}"

case "$MODE" in
  connect)
    echo "=== Starting Spark Unified Server (Thrift + Connect) ==="
    echo "  Thrift JDBC : jdbc:hive2://localhost:${SPARK_THRIFT_PORT:-10000}"
    echo "  Connect gRPC: sc://localhost:${SPARK_CONNECT_PORT:-15002}"
    echo "  Spark UI    : http://localhost:4040"
    echo "  Profile     : driver.memory=${SPARK_DRIVER_MEMORY:-2g}, master=local[${SPARK_CORES:-*}]"
    echo ""
    echo "Both dbt (via Thrift) and notebooks (via Connect) share the same"
    echo "SparkContext — all jobs appear in a single Spark UI."

    # Start Thrift Server (HiveServer2). Spark Connect is enabled via
    # spark.plugins in spark-defaults.conf, so it starts in the same JVM.
    #
    # Container-DNS overrides:
    #   - s3a endpoint points at the `ministack` container, not localhost.
    #   - Nessie / Polaris URIs likewise point at container names.
    # These override the localhost defaults in spark-defaults.conf (which are
    # the fallback for local, non-Docker Spark).
    $SPARK_HOME/sbin/start-thriftserver.sh \
      --master "local[${SPARK_CORES:-*}]" \
      --conf "spark.driver.memory=${SPARK_DRIVER_MEMORY:-2g}" \
      --conf "spark.connect.grpc.binding.port=${SPARK_CONNECT_PORT:-15002}" \
      --conf "spark.hive.server2.thrift.port=${SPARK_THRIFT_PORT:-10000}" \
      --conf "spark.hadoop.fs.s3a.endpoint=http://ministack:4566" \
      --conf "spark.sql.catalog.nessie_catalog.uri=http://nessie:19120/api/v2" \
      --conf "spark.sql.catalog.polaris_catalog.uri=http://polaris:8181/api/catalog" 2>&1

    sleep 5

    PID_FILE=$(ls /tmp/spark-*.pid 2>/dev/null | head -1)

    if [ -z "$PID_FILE" ]; then
      echo "ERROR: Spark Unified Server failed to start. Logs:"
      cat $SPARK_HOME/logs/*.out 2>/dev/null || true
      exit 1
    fi

    PID=$(cat "$PID_FILE")
    echo "Spark Unified Server running (PID: $PID)"

    # Forward logs to stdout
    tail -F $SPARK_HOME/logs/*.out 2>/dev/null &

    # Wait for process — exit if it dies (Docker will restart)
    while kill -0 "$PID" 2>/dev/null; do
      sleep 5
    done

    echo "Spark Unified Server stopped unexpectedly"
    exit 1
    ;;

  history)
    echo "=== Starting Spark History Server ==="
    echo "  UI: http://localhost:18080"

    $SPARK_HOME/sbin/start-history-server.sh 2>&1

    sleep 3

    PID_FILE=$(ls /tmp/spark-*.pid 2>/dev/null | head -1)

    if [ -z "$PID_FILE" ]; then
      echo "ERROR: History Server failed to start. Logs:"
      cat $SPARK_HOME/logs/*.out 2>/dev/null || true
      exit 1
    fi

    PID=$(cat "$PID_FILE")
    echo "History Server running (PID: $PID)"

    tail -F $SPARK_HOME/logs/*.out 2>/dev/null &

    while kill -0 "$PID" 2>/dev/null; do
      sleep 5
    done

    echo "History Server stopped unexpectedly"
    exit 1
    ;;

  *)
    exec "$@"
    ;;
esac
