const { Sql } = require('./node/sql');
const { Mail } = require('./node/mail');
const { WindModel, Consumption } = require('./node/wind');
const { router } = require('./node/router');
const settings = require('./settings');

const express = require('express');

let sql = new Sql(settings.sql);
let mail = new Mail(settings.mail);
let windModel = new WindModel(1500);
let consumption = new Consumption();
windModel.start();
const app = express();
router(app, sql, mail, windModel, consumption);

app.listen(settings.port, () => {
  let now = (new Date()).toISOString();
  let string = `${now}\tExpress: ${settings.port}\tAPI web server started.`;
  console.log(string);
})
