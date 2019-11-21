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
