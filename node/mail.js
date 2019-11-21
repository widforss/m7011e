const { Curl, CurlUseSsl } = require('node-libcurl');

class Mail {
  constructor(settings) {
    this.settings = settings;
  }

  send(code, receiver) {
    setTimeout(send, 0, code, receiver, this.settings, Math.random() * 2000);
  }
}

function send(code, receiver, settings, delay) {
  rawEmail = (`To: ${receiver}\n
               From: ${settings.sender}\n
               Subject: M7011E authentication\n
               \n
               Authentication code: ${code}\n
               \n
               Your email was entered as username for login to the 
               M7011E API. Enter the provided code 
               on the login page to authenticate to the service.\n
               \n
               If you did not expect this email, you can safely ignore 
               it.\n
               .\n
               `).replace(/^               /gm, '')
                 .replace(/\n(?=[^\n])/gm, '')
                 .replace(/\n\n/gm, '\r\n');

  let curl = new Curl();
  let linesRead = 0;

  curl.setOpt(Curl.option.USERNAME, settings.username);
  curl.setOpt(Curl.option.PASSWORD, settings.password);
  curl.setOpt(Curl.option.URL, settings.url);
  curl.setOpt(Curl.option.USE_SSL, CurlUseSsl.All);
  curl.setOpt(Curl.option.MAIL_FROM, settings.sender);
  curl.setOpt(Curl.option.UPLOAD, true)
  curl.setOpt(Curl.option.MAIL_RCPT, [receiver]);

  curl.setOpt(Curl.option.READFUNCTION, (buffer, size, nmemb) => {
    const data = rawEmail[linesRead]
    if (linesRead === rawEmail.length || size === 0 || nmemb === 0) {
      return 0
    }
    const ret = buffer.write(data)
    linesRead++
    return ret
  })
  
  curl.on('end', (statusCode, body) => {
    curl.close();
  })
  
  curl.on('error', error => {
    curl.close();
    if (delay > 40000) {
      console.error(error)
    } else {
      setTimeout(send, 0, code, receiver, settings, Math.random() * delay * 2);
    }
  })

  let domain_idx = receiver.search(/@.+$/) + 1;
  let known_domain =
      settings.domains.includes(receiver.slice(domain_idx));
  let known_address = settings.emails.includes(receiver);
  if (domain_idx == 0 || !(known_domain || known_address)) return;

  curl.perform();
}

module.exports = { Mail };
