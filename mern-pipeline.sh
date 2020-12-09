#!/bin/bash

# general dependencies:
#
#   docker-compose
#   lsof

VERSION=0.0.6
PROGNAME=$(basename $0)

function usage {
  echo
  echo "Usage:"
  echo "  sh "$PROGNAME" COMMAND [options] DIR"
  echo "  sh "$PROGNAME" -h|--help"
  echo
  echo "The DIR parameter is a build’s context"
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
  echo "  --domain            Server name (default: localhost)"
  echo "  --subnet            Docker subnet for container networking"
  echo "                      already configure. (default: 10.0.0.0/24)"
  echo "  --env-file          Read in a file of environment variables"
  echo "  --branch            Specify source git branch"
  echo "  --api-repository    Remote or local the Api service repository"
  echo "  --web-repository    Remote or local the Web service repository"
  echo "  --mongo-username    Create a new user and set that user's password."
  echo "                      This user is created in the admin authentication"
  echo "                      database and given the role of root, which"
  echo "                      is a superuser role (default: admin)"
  echo "  --mongo-password    Use than 8 digits passphrase"
  echo "                      Even a long passphrase can be quite useless"
  echo "                      if it is a regular word from a dictionary."
  echo "                      Randomize letters, numbers, and symbols mixing"
  echo "                      in the uppercase letters in your otherwise"
  echo "                      lowercase passphrase and vice versa."
  echo
  echo "Examples:"
  echo "  sh "$PROGNAME" up --domain example.com /app"
  echo "  sh "$PROGNAME" stop /app"
}

function freeport {
  local port

  while :; do
    port=$(shuf -i 1024-49151 -n 1)

    if [[ ! $(lsof -i :$port) ]]; then
      echo $port
      break
    fi
  done
}

function signand {
  if [[ ! -f $1 ]]; then
    < /dev/urandom tr -dc A-Za-z0-9 | head -c32 > $1
  fi

  cat $1
}

for progname in docker docker-compose lsof; do
  which $progname &> /dev/null

  if [[ $? == 1 ]]; then
    echo "You required install: "$progname
    exit 1
  fi
done

GETOPT_ARGS=$(getopt -o hvd -l "help","version","subnet:","domain:","env-file:","branch:","api-repository:","web-repository:","mongo-username:","mongo-password:" -n "$PROGNAME" -- "$@")

MODE=
SUBNET="10.0.0.0/24"
DOMAIN="localhost"
BRANCH=
ENV_FILE=
API_PORT=$(freeport)
API_REPOSITORY=
WEB_PORT=$(freeport)
WEB_REPOSITORY=
MONGO_PORT=$(freeport)
MONGO_USERNAME="admin"
MONGO_PASSWORD=

if [[ $? != 0 ]]; then
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
      MODE=$1
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
    --branch)
      shift
      BRANCH=$1
      shift
      ;;
    --env-file)
      shift
      ENV_FILE=$1
      shift
      ;;
    --api-repository)
      shift
      API_REPOSITORY=$1
      shift
      ;;
    --web-repository)
      shift
      WEB_REPOSITORY=$1
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

if [[ ! $2 ]]; then
  echo "Expected DIR parameter is a build’s context"
  exit 1
fi

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

if [[ ! $ENV_FILE ]]; then
  ENV_FILE=.env

  if [[ ! -f $ENV_FILE ]]; then
    echo "The file specified in --env-file was not found"
    exit 1
  fi
fi

if [[ ! $API_REPOSITORY ]]; then
  echo "Parameter --api-repository is required"
  exit 1
fi

if [[ ! $WEB_REPOSITORY ]]; then
  echo "Parameter --web-repository is required"
  exit 1
fi

if [[ ! $MONGO_PASSWORD ]]; then
  MONGO_PASSWORD=$(signand .mongo_password)
fi

for dir in ./nginx ./api ./web; do
  if [[ -d $dir ]]; then
    rm -rf $dir
  fi

  mkdir $dir
done

if [[ $BRANCH ]]; then
  git clone -b $BRANCH --single-branch $API_REPOSITORY ./api
  git clone -b $BRANCH --single-branch $WEB_REPOSITORY ./web
else
  git clone $API_REPOSITORY ./api
  git clone $WEB_REPOSITORY ./web
fi

cat << EOF > ./web/.env
NODE_ENV=$NODE_ENV
$(cat $ENV_FILE)
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
    proxy_pass http://$GATEWAY:$API_PORT;
    proxy_set_header Host $DOMAIN;
    proxy_set_header Origin \$scheme://\$host;
    proxy_http_version 1.1;
  }

  location @web {
    proxy_pass http://$GATEWAY:$WEB_PORT;
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
      - "$MONGO_PORT:27017"
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
      - "$API_PORT:3000"
    volumes:
      - ./storage:/app/storage
    environment:
      - NODE_ENV=$NODE_ENV
      - MONGO_URL=$GATEWAY:$MONGO_PORT
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
      - "$WEB_PORT:3000"
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
  docker-compose up --build $MODE
  exit
fi

usage
exit 1
