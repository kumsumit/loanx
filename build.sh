--dart-define=LOANX_SERVER_ADDRESS=127.0.0.1:4433
--dart-define=LOANX_SERVER_NAME=localhost
--dart-define=LOANX_SERVER_CERTIFICATE_BASE64=<base64-of-local-development-CA-PEM>

--dart-define=LOANX_SERVER_ADDRESS=10.0.2.2:4433
--dart-define=LOANX_SERVER_NAME=localhost

--dart-define=LOANX_SERVER_ADDRESS=api.loanx.kumpali.com:443
--dart-define=LOANX_SERVER_NAME=api.loanx.kumpali.com
--dart-define=LOANX_SERVER_CERTIFICATE_BASE64=<base64-of-ISRG-Root-X1-PEM>

Important: with the current Rust code, the third value must be the trusted CA root PEM—use Let’s Encrypt’s ISRG Root X1 public certificate—not:
- /etc/letsencrypt/live/api.loanx.kumpali.com/fullchain.pem
- cert.pem
- privkey.pem — never embed or share this
Your server itself should use:
- fullchain.pem as its server certificate chain
- privkey.pem as its private key
Base64 encoding a PEM without line breaks:
base64 < ISRG_Root_X1.pem | tr -d '\n'
The server must also accept QUIC traffic on UDP 443; HTTPS/TCP alone will not work with this app’s current transport.