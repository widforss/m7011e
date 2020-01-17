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

dataCounter = 0;
function refreshUserData() {
  setTimeout(refreshUserData, 1000);

  sql.selectAccount((err, res) => {
    if (err) {
      console.error(err);
      return;
    }
    
    let accounts = res.rows.map((account) => {
      [x, y] = account.coordinates;
      if (dataCounter % 10 == 0) {
        account.consumption = consumption.get_local();
      }
      account.production = windModel.production(x, y);

      let netProd = account.production - account.consumption;
      if (netProd >= 0) {
        account.buffer += netProd * account.tobuffer;
      } else {
        account.buffer += netProd * account.frombuffer;
      }

      account.blackout = Math.random() / settings.blackout <= 1;

      return {
        _id_public: account._id_public,
        consumption: account.consumption,
        production: account.production,
        buffer: account.buffer,
        blackout: account.blackout,
      }
    });

    sql.updateAccountData(JSON.stringify(accounts), (err) => {
      dataCounter++;
      if (err) {
        console.error(err);
        return;
      }
    });
  });

  sql.selectCoal((err, res) => {
    if (err) {
      console.error(err);
      return;
    }

    sql.getDemand((err, demand) => {
      if (err || !demand.rowCount) {
        console.error(err);
        return;
      }

      let coal = {
        status: res.rows[0].start,
        production: res.rows[0].production,
        buffer: res.rows[0].buffer,
      };
      if (res.rows[0].status == 'started') {
        coal.buffer += coal.production * res.rows[0].tobuffer;
      } else {
        coal.buffer -= demand.rows[0].demand * res.rows[0].frombuffer;
      }

      sql.updateCoalData(JSON.stringify(coal), (err, res) => {
        if (err) {
          console.error(err);
          return;
        }
      });
    });    
  });
}
refreshUserData();