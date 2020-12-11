#!/bin/bash

# This is Unit test for mern-pipeline.sh
#
# For a colored background are the commonly used color codes
#     reset = 0, black = 40, red = 41, green = 42, yellow = 43, blue = 44,
#     magenta = 45, cyan = 46, and white=47
#
# echo -e "\e[1;31m This is red text \e[0m"

PROGNAME=./mern-pipeline.sh
BUFFER=./.buffer.test
CTX=$(mktemp -d)
REPOSITORY=$(git remote get-url --all origin)

function it {
  local status=$? output=$(cat $BUFFER) message

  if [[ $status == 0 ]] && [[ $output =~ $1 ]]; then
    message="\e[1;32m ✓ \e[0m "$2
  fi

  if [[ $status > 0 ]] && [[ $output =~ $1 ]] && [[ $status == $3 ]]; then
    message="\e[1;32m ✓ \e[0m "$2
  fi

  if [[ $message ]]; then
    echo -e $message
  else
    echo -e "\e[1;31m ✗ \e[0m "$2
    echo -e "\e[1;45m $output \e[0m"
  fi
}

function dotenv {
  grep $1 $2 | egrep -v "^#"| cut -f2 -d "="
}

echo
sh $PROGNAME -h > $BUFFER
it "Usage:" "Positive: Must be show help # -h"
echo

sh $PROGNAME --help > $BUFFER
it "Usage:" "Positive: Must be show help # --help"
echo

sh $PROGNAME -v > $BUFFER
it [0-9]+\.[0-9]+\.[0-9]+ "Positive: Print version number # -v"
echo

sh $PROGNAME --version > $BUFFER
it [0-9]+\.[0-9]+\.[0-9]+ \
  "Positive: Print version number # --version"
echo

sh $PROGNAME > $BUFFER 2>&1
it "COMMAND" \
  "Negative: Must be exit SIGN if COMMAND is empty" 1
echo

sh $PROGNAME stop $CTX > $BUFFER 2>&1
it "Can't find a suitable configuration file" \
  "Negative: Must be exit SIGN if docker-compose.yml not be created" 1
echo

sh $PROGNAME up > $BUFFER 2>&1
it "Expected DIR parameter" \
  "Negative: Must be exit SIGN if DIR parameter not found" 1
echo

sh $PROGNAME up \
  --subnet 10.0.0.0 $CTX > $BUFFER 2>&1
it "Expected the Docker subnet" \
  "Negative: Subnet should be in CIDR format" 1
echo

sh $PROGNAME up --subnet 10.0.0/32 $CTX > $BUFFER 2>&1
it "Expected the Docker subnet" \
  "Negative: Subnet should be in CIDR format" 1
echo

sh $PROGNAME up --domain example $CTX > $BUFFER 2>&1
it "Expected domain" \
  "Negative: Domain should be RFC 882 standart" 1
echo

sh $PROGNAME up --env-file example $CTX > $BUFFER 2>&1
it "--env-file" \
  "Negative: If specified # --env-file, file .env should be exist" 1
echo

sh $PROGNAME up --api-repository $REPOSITORY $CTX > $BUFFER 2>&1
it "--web-repository" \
  "Negative: Must be exit SIGN if not # --web-repository" 1
echo

sh $PROGNAME up --web-repository $REPOSITORY $CTX > $BUFFER 2>&1
it "--api-repository" \
  "Negative: Must be exit SIGN if not # --api-repository" 1
echo

# NOTE
# Solution ERROR: Pool overlaps with other one on this address space
#     docker network prune -f

cat << EOF > $CTX/.env
TEST=1
EOF

NODE_ENV=testing sh $PROGNAME up \
  -d \
  --domain example.com \
  --subnet 10.0.0.0/24 \
  --env-file ./.env \
  --api-repository $REPOSITORY \
  --web-repository $REPOSITORY \
  $CTX > $BUFFER
it "Successfully" \
  "Positive: Create and start containers in detached mode & NODE_ENV environment"
echo

stat $CTX/web/.env > $BUFFER
it "File" \
  "Positive: File .env should be extends in the Web directory"
echo

dotenv "NODE_ENV" $CTX/web/.env > $BUFFER
it "testing" \
  "Positive: File .env should be conents NODE_ENV value"
echo

dotenv "TEST" $CTX/web/.env > $BUFFER
it "1" \
  "Positive: File .env should be conents custom TEST value"
echo

sh $PROGNAME stop \
  $CTX > $BUFFER
it "" "Positive: Stop services"
echo

cd $CTX
docker-compose rm -f
