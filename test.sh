#!/bin/bash

# For a colored background are the commonly used color codes
#     reset = 0, black = 40, red = 41, green = 42, yellow = 43, blue = 44,
#     magenta = 45, cyan = 46, and white=47
#
# echo -e "\e[1;31m This is red text \e[0m"

PROGNAME=mern-pipeline.sh
TEMPDIR=$(mktemp -d)
REPOSITORY=$(git remote get-url --all origin)

function it {
  local status=$? message="31m ✗"

  if [[ $status > 0 ]] && [[ $status == $1 ]]; then
    message="32m ✓"
  fi

  if [[ $status == 0 ]] && [[ $(cat) =~ $1 ]]; then
    message="32m ✓"
  fi

  echo -e "  \e[1;$message \e[0m " $2
}

sh $PROGNAME ; it 1 \
  "Negative: Must be exit SIGN if less options"
echo

sh $PROGNAME \
  -h | it "Usage:" \
  "Positive: Must be show help # -h"
echo

sh $PROGNAME \
  --help | it "Usage:" \
  "Positive: Must be show help # --help"
echo

sh $PROGNAME \
  -v | it [0-9]+\.[0-9]+\.[0-9]+ \
  "Positive: Print version number # -v"
echo

sh $PROGNAME \
  --version | it [0-9]+\.[0-9]+\.[0-9]+ \
  "Positive: Print version number # --version"
echo

sh $PROGNAME stop $TEMPDIR; it 1 \
  "Negative: Must be exit SIGN if docker-compose.yml not be created"
echo

sh $PROGNAME up ; it 1 \
  "Negative: Must be exit SIGN if DIR parameter not found"
echo

sh $PROGNAME up \
  --subnet 10.0.0.0 ; it 1 \
  "Negative: Subnet should be in CIDR format"
echo

sh $PROGNAME up \
  --subnet 10.0.0/32 ; it 1 \
  "Negative: Subnet should be in CIDR format"
echo

sh $PROGNAME up \
  --domain example ; it 1 \
  "Negative: Domain should be RFC 882 standart"
echo

sh $PROGNAME up \
  --env-file example \
  $TEMPDIR; it 1 \
  "Negative: If specified # --env-file, file .env should be exist"
echo

sh $PROGNAME up $TEMPDIR; it 1 \
  "Negative: If # --env-file is empty, file .env should be exist in DIR build’s context"
echo

echo '' > $TEMPDIR/.env

sh $PROGNAME up \
  --api-repository $REPOSITORY $TEMPDIR; it 1 \
  "Negative: Must be exit SIGN if not # --web-repository"
echo

sh $PROGNAME up \
  --web-repository $REPOSITORY $TEMPDIR; it 1 \
  "Negative: Must be exit SIGN if not # --api-repository"
echo

# sh $PROGNAME up \
#   --api-repository $REPOSITORY \
#   --web-repository $REPOSITORY \
#   $TEMPDIR ; it 1 \
#   "Negative: The file specified in --env-file. File is not found"
# echo
