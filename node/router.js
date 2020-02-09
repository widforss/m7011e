const os = require("os");
const cors = require('cors');
const express = require('express');
const handlebars = require('express-handlebars');
const cookieParser = require('cookie-parser');
const bodyParser = require("body-parser");
const formData = require("express-form-data");
const fs = require('fs');
const gm = require('gm');

const emailChar = /^[0-9a-zA-Z!#$%&'\*+\-/=?^_`{|}~."(),:;<>@[\\\]]*$/;
const atStruct = /^.+@.+$/;

let loggedIn = {};

function router(app, sql, mail, wind, consumption) {
  app.use(cors())
    .options('*', cors())
    .engine('.hbs', handlebars({ extname: '.hbs', cache: false }))
    .set('view engine', '.hbs')
    .use('/static', express.static('static'))
    .use(cookieParser());

  const options = {
    uploadDir: os.tmpdir(),
    autoClean: true
  };
  app.use(formData.parse(options));
  app.use(formData.format());
  app.use(formData.stream());
  app.use(formData.union());

  app.use(bodyParser.json());

  app.use('/prosumer', function (req, res, next) {
    authenticate(req, res, sql, (isAuthenticated) => {
      if (isAuthenticated) {
        next();
      } else {
        res.redirect('/login');
      }
    });
  });

  app.use('/manager', function (req, res, next) {
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

  app.use('/api/manager/*', (req, res, next) => {
    isManager(
      req,
      sql,
      () => next(),
      () => res.sendStatus(403),
    );
  })

  app.get('/', function (req, res) {
    isManager(
      req,
      sql,
      () => res.redirect('/manager'),
      () => res.redirect('/prosumer'),
    );
  });

  app.get('/prosumer', function (req, res) {
    isManager(
      req,
      sql,
      () => res.redirect('/manager'),
      () => res.render('prosumer', {
        layout: false,
      }),
    );
  });

  app.get('/manager', function (req, res) {
    isManager(
      req,
      sql,
      () => res.render('manager', {
        layout: false,
      }),
      () => res.redirect('/prosumer'),
    );
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

  app.get('/auth', function (req, res) {
    authenticate(req, res, sql, (isAuthenticated) => {
      if (isAuthenticated) {
        res.redirect('/');
      } else {
        res.render('auth', {
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

  app.get('/api/manager/coal', (req, res) => {
    sql.selectCoal((err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.post('/api/manager/settings', (req, res) => {
    let token = req.cookies.token;

    sql.setCoalSettings(token, req.body, (err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.get('/api/manager/users', (req, res) => {
    sql.selectAccount((err, sqlres) => {
      if (err) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows);
    }, req.query.email);
  });

  app.get('/api/manager/price', (req, res) => {
    let price =
      1.3 + 0.1 * (consumption.get() / consumption.typ) / (wind.avg() / wind.typ);
    res.send({ price });
  });

  app.post('/api/manager/price/:price', (req, res) => {
    let token = req.cookies.token;
    let price = parseFloat(req.params.price);

    sql.setPrice(token, price, (err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.post('/api/manager/block/:id/:seconds', (req, res) => {
    let id = req.params.id;
    let seconds = parseInt(req.params.seconds, 10);

    sql.blockAccount(id, seconds, (err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.get('/api/manager/active', (req, res) => {
    res.send(Object.keys(loggedIn));
  });

  app.get('/api/manager/runas', (req, res) => {
    let receiver = req.query.email;
    if (!receiver || !receiver.match(atStruct) || !receiver.match(emailChar)) {
      res.sendStatus(400);
      return;
    }

    sql.selectAccount((err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(403);
        return;
      }

      sql.createAccountSession(receiver, (err, sqlres) => {
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
    }, receiver);
  });

  app.get('/api/manager/demand', (req, res) => {
    sql.getDemand((err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.post('/api/manager/account/properties', (req, res) => {
    sql.updateAccountProperties(req.body, (err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.get('/api/account', (req, res) => {
    let token = req.cookies.token;

    sql.getAccount(token, (err, sqlres) => {
      if (err || !sqlres.rowCount) {
        console.log(err, sqlres)
        res.sendStatus(500);
        return;
      }

      let email = sqlres.rows[0].email;
      let timeout = loggedIn[email];
      if (timeout) {
        clearTimeout(timeout)
      }
      timeout = setTimeout(() => delete loggedIn[email], 6000);
      loggedIn[email] = timeout;

      res.send(sqlres.rows[0]);
    });
  });

  app.post('/api/settings', (req, res) => {
    let token = req.cookies.token;

    sql.setSettings(token, req.body, (err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.get('/api/avatar/:id', (req, res) => {
    let token = req.cookies.token;

    sql.selectAccountAvatar(token, req.params.id, (err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.type(sqlres.rows[0].format.toLowerCase());
      res.send(sqlres.rows[0].image);
    })
  });

  app.post('/api/avatar', (req, res) => {
    let token = req.cookies.token;

    if (!req.files['avatar']) {
      res.sendStatus(400);
      return;
    }

    gm(req.files['avatar'])
    .format({bufferStream: true}, function(err, format) {
      if (err || (format !== "JPEG" && format !== "PNG")) {
        res.sendStatus(400);
        return;
      }

      this.resize(640, 480)
      .toBuffer(format, function (err, buffer) {
        if (err) {
          res.sendStatus(500);
          return;
        }

        sql.upsertAccountAvatar(token, format, buffer, (err) => {
          if (err) {
            res.sendStatus(500);
            return;
          }
          res.sendStatus(200);
        });
      })
    })
  });

  app.get('/api/wind', (req, res) => {
    let token = req.cookies.token;

    sql.getAccount(token, (err, sqlres) => {
      if (err || !sqlres.rowCount || !sqlres.rows[0].coordinates) {
        res.sendStatus(500);
        return;
      }

      [x, y] = sqlres.rows[0].coordinates;
      let response;
      try {
        response = { velocity: wind.get(x, y) };
      } catch (e) {
        res.sendStatus(404);
      }

      res.send(response);
    });
  });

  app.get('/api/data', (req, res) => {
    let token = req.cookies.token;
    sql.getAccountData(token, (err, sqlres) => {
      if (err || !sqlres.rowCount) {

        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
  });

  app.get('/api/price', (req, res) => {
    sql.getPrice((err, sqlres) => {
      if (err || !sqlres.rowCount) {
        res.sendStatus(500);
        return;
      }

      res.send(sqlres.rows[0]);
    });
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

    let loginCode = req.query.code;
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
  res.cookie('token', "", {expire: new Date(1)});
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
      httpOnly: false,
    })

    callback(true);
  });
}

function isManager(req, sql, is, not) {
  let token = req.cookies.token;

  if (token === undefined) {
    not();
    return;
  }

  sql.getAccount(token, (err, sqlres) => {
    if (err || !sqlres.rowCount || !sqlres.rows[0].manager) {
      not();
    } else {
      is();
    }
  });
}

module.exports = { router }
