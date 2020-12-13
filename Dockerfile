FROM alpine
WORKDIR /app
COPY . .

RUN apk add yarn \
  && yarn install --production

EXPOSE 3000
CMD [ "yarn", "start", "-p", "3000" ]
