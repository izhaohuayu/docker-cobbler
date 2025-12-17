docker run -d \
  -p 8080:80 \
  -p 25151:25151 \
  -e SERVER_IP_V4=127.0.0.1 \
  -e ROOT_PASSWORD=YourPassword \
  -v $PWD/lib:/var/lib/cobbler \
  -v $PWD/www:/var/www/cobbler \
  -v $PWD/dhcpd:/var/lib/dhcpd \
  --name cobbler \
  cobbler:3.3.3
