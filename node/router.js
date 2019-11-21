const cors = require('cors');

const emailChar = /^[0-9a-zA-Z!#$%&'\*+\-/=?^_`{|}~."(),:;<>@[\\\]]*$/;
const atStruct = /^.+@.+$/;

function router(app, sql, mail, wind, consumption) {
  app.use(cors())
  app.options('*', cors());

  app.use('/api/*', function (req, res, next) {
    let token = req.query.token;

    sql.checkAccountSession(token, (err, sqlres) => {
      if (err || !sqlres.rowCount || !sqlres.rows[0].authenticated) {
        res.sendStatus(403);
        return;
      }

      next()
    });
  })

  app.get('/api/wind/:x/:y', (req, res) => {
    let x = parseInt(req.params.x, 10);
    if (isNaN(x)) {
      res.sendStatus(400);
      return;
    }
  
    let y = parseInt(req.params.y, 10);
    if (isNaN(x)) {
      res.sendStatus(400);
      return;
    }

    let response;
    try {
      response = { velocity: wind.get(x, y) };
    } catch (e) {
      res.sendStatus(404);
    }

    res.send(response);
  });

  app.get('/api/wind/:x/:y', (req, res) => {
    let x = parseInt(req.params.x, 10);
    if (isNaN(x)) {
      res.sendStatus(400);
      return;
    }
  
    let y = parseInt(req.params.y, 10);
    if (isNaN(x)) {
      res.sendStatus(400);
      return;
    }

    let response;
    try {
      response = { velocity: wind.get(x, y) };
    } catch (e) {
      res.sendStatus(404);
    }

    res.send(response);
  });

  app.get('/api/consumption', (req, res) => {
    res.send({ consumption: consumption.get() });
  });

  app.get('/api/price', (req, res) => {
    let price =
      1 + 0.5 * (consumption.get() / consumption.typ) / (wind.avg() / wind.typ);
    res.send({ price });
  });

  app.get('/auth/login', (req, res) => {
    if (req.query.gdpr != "true") {
      res.sendStatus(451);
      return;
    }

    let receiver = req.query.email;
    if (!receiver || !receiver.match(atStruct) || !receiver.match(emailChar)) {
      res.sendStatus(400);
      return;
    }

    sql.getAccountCode(receiver, (err, sqlres) => {
      if (err) {
        res.sendStatus(500);
        return;
      }
      if (!sqlres.rowCount || !sqlres.rows[0].code) {
        res.sendStatus(429);
        return;
      }

      mail.send(sqlres.rows[0].code, receiver);
      res.send({success: true});
    });
  });

  app.get('/auth/code', (req, res) => {
    let email = req.query.email;
    if (!email || !email.match(atStruct) || !email.match(emailChar)) {
      res.sendStatus(400);
      return;
    }

    let loginCode = parseInt(req.query.code, 10);
    if(isNaN(loginCode)) {
      res.sendStatus(400);
      return;
    }

    sql.checkAccountCode(email, loginCode, (err, sqlres) => {
      if (err) {
        res.sendStatus(500);
        return;
      }
      if (!sqlres.rowCount || !sqlres.rows[0].status) {
        res.sendStatus(403);
        return;
      }

      sql.assertAccount(email, (err, sqlres) => {
        if (err) {
          res.sendStatus(500);
          return;
        }
        if (!sqlres.rowCount || !sqlres.rows[0].status) {
          res.sendStatus(403);
          return;
        }

        sql.createAccountSession(email, (err, sqlres) => {
          if (err || !sqlres.rowCount) {
            res.sendStatus(500);
            return;
          }
          res.send(sqlres.rows[0]);
        });
      });
    });
  });

  app.get('/auth/revoke', (req, res) => {
    let session = req.query.session;
    if (!session) {
      res.sendStatus(400);
      return;
    }

    sql.revokeAccountSession(session, (err, sqlres) => {
      if (err) {
        res.sendStatus(500);
        return;
      }
      if (!sqlres.rowCount) {
        res.sendStatus(403);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });
}

module.exports = { router }
