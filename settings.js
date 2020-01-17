module.exports = {
  port: 8008,
  blackout: 0.25,
  sql: {
    connection: {
      user: replaceSqlUsername,
      host: replaceSqlHostname,
      database: replaceSqlDatabaseName,
      password: replaceSqlPassword,
      port: replaceSqlPortNumber,
      ssl: replaceSqlSslBoolean,
    }
  },
  mail: {
    sender: replaceSmtpSender,
    username: replaceSmtpUsername,
    password: replaceSmtpPassword,
    url: replaceSmtpUrl,
    length: 6,
    domains: [
      "student.ltu.se",
      "ltu.se",
      "antarkt.is",
    ],
    emails: [],
  },
}
