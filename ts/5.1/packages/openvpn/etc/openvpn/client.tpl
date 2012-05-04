dev tap
remote $OPENVPN_SERVER
port $OPENVPN_PORT
proto $OPENVPN_PROTO
tls-client
pull
pkcs12 client.p12
keysize 256
comp-lzo
verb 1
persist-tun
persist-key
persist-remote-ip
persist-local-ip
