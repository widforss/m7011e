const { Pool, Client } = require('pg');
const { PgPoolError } = require('./error');

class Sql {
  constructor(settings) {
    this.settings = settings;
    this.pool = new Pool(settings.connection);

    this.pool.on('error', (err, client) => {
      throw new PgPoolError();
    })
  }
  getAccountCode(receiver, callback) {
    let query = `SELECT GetAccountCode($1) AS code;`;
    this.query_(query, [receiver], callback);
  }

  checkAccountCode(receiver, loginCode, callback) {
    let query = `SELECT CheckAccountCode($1, $2) AS status;`;
    this.query_(query, [receiver, loginCode], callback);
  }

  assertAccount(receiver, callback) {
    let query = `SELECT AssertAccount($1) AS status`;
    this.query_(query, [receiver], callback);
  }

  createAccountSession(receiver, callback) {
    let query = `SELECT CreateAccountSession($1) AS session`;
    this.query_(query, [receiver], callback);
  }

  checkAccountSession(token, callback) {
    let query = `SELECT CheckAccountSession($1) AS authenticated`;
    this.query_(query, [token], callback);
  }

  revokeAccountSession(uuid, callback) {
    let query = `SELECT RevokeAccountSession($1) AS status`;
    this.query_(query, [uuid], callback);
  }
  
  setSettings(token, body, callback) {
    let query = `SELECT * FROM setSettings($1, $2);`;
    this.query_(query, [token, body], callback);
  }
  
  getAccount(token, callback) {
    let query = `SELECT * FROM getAccount($1);`;
    this.query_(query, [token], callback);
  }
  
  selectAccount(callback, optional_email) {
    if (optional_email) {
      let query = `SELECT * FROM Account WHERE NOT manager AND email = $1`;
      this.query_(query, [optional_email], callback);
    } else {
      let query = `SELECT * FROM Account WHERE NOT manager;`;
      this.query_(query, [], callback);
    }
  }

  updateAccountProperties({_id_public, email, active}, callback) {
    let query = `SELECT * FROM updateAccountProperties($1, $2, $3);`;
    this.query_(query, [_id_public, email, active], callback);
  }

  blockAccount(id, seconds, callback) {
    let query = `SELECT * FROM blockAccount($1, $2);`;
    this.query_(query, [id, seconds], callback);
  }
  
  updateAccountData(data, callback) {
    let query = `SELECT * FROM updateAccountData($1);`;
    this.query_(query, [data], callback);
  }

  getAccountData(token, callback) {
    let query = `SELECT * FROM getAccountData($1);`;
    this.query_(query, [token], callback);
  }

  upsertAccountAvatar(token, format, data, callback) {
    let query = `SELECT * FROM upsertAccountAvatar($1, $2, $3);`;
    this.query_(query, [token, format, data], callback);
  }
  
  selectAccountAvatar(token, id, callback) {
    let query = `SELECT * FROM selectAccountAvatar($1, $2);`;
    this.query_(query, [token, id], callback);
  }

  setPrice(token, price, callback) {
    let query = `SELECT * FROM setPrice($1, $2);`;
    this.query_(query, [token, price], callback);
  }
  
  setCoalSettings(token, body, callback) {
    let query = `SELECT * FROM setCoalSettings($1, $2);`;
    this.query_(query, [token, body], callback);
  }
  
  getPrice(callback) {
    let query = `SELECT * FROM price;`;
    this.query_(query, [], callback);
  }
  
  getDemand(callback) {
    let query = `SELECT
        CASE WHEN SUM(consumption - account.production + account.bufferUse) > 0
        THEN SUM(consumption - account.production + account.bufferUse) + MIN(coal.normalDemand)
        ELSE MIN(coal.normalDemand) END AS demand
        FROM account
        JOIN coal ON TRUE
        WHERE NOT manager;`;
    this.query_(query, [], callback);
  }

  selectCoal(callback) {
    let query = `SELECT * FROM Coal;`;
    this.query_(query, [], callback);
  }

  setCoalSettings(token, data, callback) {
    let query = `SELECT * FROM setCoalSettings($1, $2);`;
    this.query_(query, [token, data], callback);
  }
  
  updateCoalData(data, callback) {
    let query = `SELECT * FROM updateCoalData($1);`;
    this.query_(query, [data], callback);
  }

  query_(query, args, callback) {
    this.pool.connect((err, client, done) => {
      if (err) {
        callback(err, null);
        return;
      }
      client.query(query, args, (err, res) => {
        done();
        callback(err, res);
      })
    })
  }
}

module.exports = { Sql };
