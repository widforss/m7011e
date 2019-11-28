const cors = require('cors');
const express = require('express');
const handlebars = require('express-handlebars');
var cookieParser = require('cookie-parser');

const emailChar = /^[0-9a-zA-Z!#$%&'\*+\-/=?^_`{|}~."(),:;<>@[\\\]]*$/;
const atStruct = /^.+@.+$/;

function router(app, sql, mail, wind, consumption) {
  app.use(cors())
    .options('*', cors())
    .engine('.hbs', handlebars({ extname: '.hbs', cache: false }))
    .set('view engine', '.hbs')
    .use('/static', express.static('static'))
    .use(cookieParser());

  app.use('/prosumer', function (req, res, next) {
    authenticate(req, res, sql, (isAuthenticated) => {
      if (isAuthenticated) {
        next();
      } else {
        res.redirect('/login');
      }
    });
  });

  app.use('/api/*', (req, res, next) => {
    authenticate(req, res, sql, (isAuthenticated) => {
      if (isAuthenticated) {
        next();
      } else {
        res.sendStatus(403);
      }
    });
  })

  app.get('/', function (req, res) {
    res.redirect('/prosumer');
  });

  app.get('/prosumer', function (req, res) {
    res.render('prosumer', {
      layout: false,
    });
  });

  app.get('/login', function (req, res) {
    authenticate(req, res, sql, (isAuthenticated) => {
      if (isAuthenticated) {
        res.redirect('/');
      } else {
        res.render('login', {
          layout: false,
        });
      }
    });
  });

  app.get('/logout', function (req, res) {
    revoke(req, res, sql, (code) => {
      if (code == 200) {
        res.redirect('/');
      } else {
        res.sendStatus(code);
      }
    });
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
      res.send({ success: true });
    });
  });

  app.get('/auth/code', (req, res) => {
    let email = req.query.email;
    if (!email || !email.match(atStruct) || !email.match(emailChar)) {
      res.sendStatus(400);
      return;
    }

    let loginCode = parseInt(req.query.code, 10);
    if (isNaN(loginCode)) {
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
          res.cookie('token', sqlres.rows[0].session, {
            maxAge: 10 * 365 * 24 * 60 * 60 * 1000,
            httpOnly: true,
          })
          res.sendStatus(200);
        });
      });
    });
  });

  app.get('/auth/revoke', (req, res) => {
    revoke(req, res, sql, (code) => {
      if (code == 200) {
        res.send({success: true});
      } else {
        res.sendStatus(code);
      }
    });
  });
}

function revoke(req, res, sql, callback) {
  let token = req.cookies.token;
  if (!token) {
    callback(400)
    return;
  }

  sql.revokeAccountSession(token, (err, sqlres) => {
    if (err) {
      callback(500)
      return;
    }
    if (!sqlres.rowCount) {
      callback(403)
      return;
    }

    res.cookie('token', token, {expire: new Date(1)});
    callback(200)
  });
}

function authenticate(req, res, sql, callback) {
  let token = req.cookies.token;

  if (token === undefined) {
    callback(false);
    return;
  }

  sql.checkAccountSession(token, (err, sqlres) => {
    if (err || !sqlres.rowCount || !sqlres.rows[0].authenticated) {
      callback(false);
      return;
    }

    res.cookie('token', token, {
      maxAge: 10 * 365 * 24 * 60 * 60 * 1000,
      httpOnly: true,
    })

    callback(true);
  });
}

module.exports = { router }
