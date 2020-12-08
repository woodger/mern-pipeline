#!/bin/bash

# general dependencies:
#
#   docker
#   docker-compose

VERSION=0.0.4
PROGNAME=$(basename $0)

function usage {
  echo
  echo "Usage:"
  echo "  "$PROGNAME" COMMAND [options] DIR"
  echo "  "$PROGNAME" -h|--help"
  echo
  echo "The DIR parameter is a build’s context. The default DIR is the"
  echo "value of the HOME shell variable"
  echo
  echo "Commands:"
  echo "  up                  Create and start containers"
  echo "  stop                Stop services"
  echo
  echo "Options:"
  echo "  -h, --help          Show this help"
  echo "  -v, --version       Print version number"
  echo "  -d                  Detached mode: Run containers in the background"
  echo "                      print new container names"
  echo "  --subnet            Docker subnet for container networking"
  echo "                      already configure. (default: 10.0.0.0/24)"
  echo "  --domain        Server name (default: localhost)"
  echo "  -k, --key           Use 8 digits passphrase or most for HMAC"
  echo "                      Even a long passphrase can be quite useless"
  echo "                      if it is a regular word from a dictionary."
  echo "                      Randomize letters, numbers, and symbols mixing"
  echo "                      in the uppercase letters in your otherwise"
  echo "                      lowercase passphrase and vice versa."
  echo "  --env-file          Read in a file of environment variables"
  echo
  echo "Examples:"
  echo "  "$PROGNAME" up --domain example.com /app"
  echo "  "$PROGNAME" stop"
}

for x in docker docker-compose; do
  which $x &> /dev/null

  if [[ $? == 1 ]]; then
    echo "You required install: "$x
    exit 1
  fi
done

GETOPT_ARGS=$(getopt -o hvd -l "help","version","subnet:","domain:","env-file:","branch:","api-repository:","web-repository:","mongo-username:","mongo-password:" -n "$PROGNAME" -- "$@")
DETACH=
SUBNET="10.0.0.0/24"
DOMAIN="localhost"
BRANCH=
API_REPO=
WEB_REPO=
MONGO_USERNAME="root"
MONGO_PASSWORD=$(< /dev/urandom tr -dc _A-Za-z-0-9 | head -c8; echo)

if [[ $? -ne 0 ]]; then
  usage
  exit 1
fi

eval set -- $GETOPT_ARGS

while :; do
  case $1 in
    -h|--help)
      usage
      exit
      ;;
    -v|--version)
      echo $VERSION
      exit
      ;;
    -d)
      DETACH=$1
      shift
      ;;
    --subnet)
      shift
      SUBNET=$1
      shift
      ;;
    --domain)
      shift
      DOMAIN=$1
      shift
      ;;
    --env-file)
      shift
      ENV_FILE=$1
      shift
      ;;
    --branch)
      shift
      BRANCH=$1
      shift
      ;;
    --api-repository)
      shift
      API_REPO=$1
      shift
      ;;
    --web-repository)
      shift
      WEB_REPO=$1
      shift
      ;;
    --mongo-username)
      shift
      MONGO_USERNAME=$1
      shift
      ;;
    --mongo-password)
      shift
      MONGO_PASSWORD=$1
      shift
      ;;
    --)
      shift
      break
      ;;
  esac
done

cd $2

if [[ $1 == "stop" ]]; then
  docker-compose stop
  exit
fi

if [[ ! $SUBNET =~ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2} ]]
then
  echo "Expected the Docker subnet as 172.17.0.0/16 for container networking"
  exit 1
fi

GATEWAY=${SUBNET%.*}.1

if [[ ! $DOMAIN == "localhost" ]] && [[ ! $DOMAIN =~ [-a-z0-9_]+\.[a-z]{2,} ]]
then
  echo "Expected domain by following the RFC 882 standart"
  exit 1
fi

if [[ $ENV_FILE ]] && [[ ! -f $ENV_FILE ]]; then
  echo "The file specified in --env-file was not found"
  exit 1
fi

if [[ ! $ENV_FILE ]] && [[ -f .env ]]; then
  ENV_FILE=.env
fi

if [[ ! $API_REPO ]]; then
  echo "Parameter --api-repo is required"
  exit 1
fi

if [[ ! $WEB_REPO ]]; then
  echo "Parameter --web-repo is required"
  exit 1
fi

for x in ./api ./web ./nginx; do
  if [[ -d $x ]]; then
    rm -rf $x
  fi

  mkdir $x
done

if [[ $BRANCH ]]; then
  git clone -b $BRANCH --single-branch $API_REPO ./api
  git clone -b $BRANCH --single-branch $WEB_REPO ./web
else
  git clone $API_REPO ./api
  git clone $WEB_REPO ./web
fi

cat << EOF > ./web/.env
NODE_ENV=$NODE_ENV
API_URL=http://$DOMAIN
EOF

cat << EOF > ./nginx/nginx.conf
server {
  listen 80;
  server_name $DOMAIN;

  gzip on;
  gzip_types text/plain text/css application/javascript application/json image/svg+xml image/png image/jpeg image/gif;

  location /api {
    try_files \$uri @api;
    root /var/storage;
  }

  location / {
    try_files \$uri @web;
    root /var/static;
  }

  location @api {
    proxy_pass http://$GATEWAY:4000;
    proxy_set_header Host $DOMAIN;
    proxy_set_header Origin \$scheme://\$host;
    proxy_http_version 1.1;
  }

  location @web {
    proxy_pass http://$GATEWAY:3000;
    proxy_set_header Host $DOMAIN;
    proxy_set_header Origin \$scheme://\$host;
    proxy_http_version 1.1;
  }
}
EOF

cat << EOF > ./docker-compose.yml
version: "3.3"
services:
  nginx:
    image: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx:/etc/nginx/conf.d
      - ./storage:/var/storage
      - ./web/static:/var/static
    networks:
      - docker_default
  mongo:
    image: mongo
    restart: unless-stopped
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_ROOT_USERNAME=$MONGO_USERNAME
      - MONGO_INITDB_ROOT_PASSWORD=$MONGO_PASSWORD
    networks:
      - docker_default
  api:
    build:
      context: ./api
    depends_on:
      - nginx
      - mongo
    restart: unless-stopped
    ports:
      - "4000:3000"
    extra_hosts:
      - "hyper-office.ru:$GATEWAY"
    volumes:
      - ./storage:/app/storage
      - ./products:/products
    environment:
      - NODE_ENV=$NODE_ENV
      - MONGO_URL=$GATEWAY:27017
      - MONGO_USERNAME=$MONGO_USERNAME
      - MONGO_PASSWORD=$MONGO_PASSWORD
    env_file:
      - $ENV_FILE
    networks:
      - docker_default
  web:
    build:
      context: ./web
    depends_on:
      - api
    restart: unless-stopped
    ports:
      - "3000:3000"
    extra_hosts:
      - "$DOMAIN:$GATEWAY"
    networks:
      - docker_default
networks:
  docker_default:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: $SUBNET
EOF

if [[ $1 == "up" ]]; then
  docker-compose up --build $DETACH
  exit
fi

usage
exit 1
