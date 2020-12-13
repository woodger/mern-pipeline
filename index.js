const http = require('http');
const minimist = require('minimist');
const express = require('express');

const argv = minimist(process.argv.slice(2));

const app = express();
const srv = app.listen(argv.p);

const {port} = srv.address();

console.log(
  `Server is running at http://0.0.0.0:${port}`
);
