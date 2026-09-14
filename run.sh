LOCAL_CERT_B64="$(base64 < ../certs/cert.pem | tr -d '\n')"

flutter run \
  --dart-define=LOANX_SERVER_ADDRESS=192.168.1.6:4433 \
  --dart-define=LOANX_SERVER_NAME=localhost \
  --dart-define=LOANX_SERVER_CERTIFICATE_BASE64="$LOCAL_CERT_B64"