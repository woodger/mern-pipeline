FROM alpine
WORKDIR /app
COPY . .

RUN apk add yarn \
  && yarn install && yarn build

EXPOSE 3000
CMD [ "yarn", "start" ]
