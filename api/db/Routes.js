'use strict';

module.exports = dbRoutes;
var validateAccount = require('../../common/auth/validateAccount.js');

function dbRoutes(app) {
  app.get('/api/db', validateAccount, require('./get.js'));
  app.get('/api/db/status', validateAccount, require('./getStatus.js'));
  app.get('/api/db/logs', validateAccount, require('./getLogs.js'));
  app.post('/api/db', validateAccount, require('./post.js'));
  app.put('/api/db', validateAccount, require('./put.js'));
  app.post('/api/db/cleanup', validateAccount, require('./cleanup.js'));
}
