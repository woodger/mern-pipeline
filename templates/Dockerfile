FROM alpine
WORKDIR /app
COPY . .

RUN apk add yarn && yarn

EXPOSE 3000
CMD [ "yarn", "start" ]
