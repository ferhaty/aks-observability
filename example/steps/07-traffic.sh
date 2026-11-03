for i in $(seq 1 30); do
  curl --fail --silent --show-error http://localhost:9898/status/200
  curl --silent --show-error --output /dev/null --write-out 'HTTP %{http_code}\n'     http://localhost:9898/status/500
  sleep 2
done
curl --fail --silent --show-error http://localhost:9898/delay/1
curl --fail --silent --show-error http://localhost:9898/metrics
