module.exports = {
  port: 8008,
  sql: {
    connection: {
      user: 'webdyn',
      host: 'localhost',
      database: 'webdyn',
      password: 'webdyn',
      port: 5432,
      ssl: false,
    }
  },
  mail: {
    sender: 'webdyn@fastmail.com',
    username: 'webdyn@fastmail.com',
    password: 'ngnl3cd6n6h4pl5c',
    url: 'smtps://smtp.fastmail.com:465',
    length: 6,
    domains: [
      "student.ltu.se",
      "ltu.se",
    ],
    emails: [],
  },
}
