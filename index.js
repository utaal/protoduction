require('coffee-script')
var log = require('./lib/log')

module.exports = {
  enableDebug: log.enableDebug,
  configRouter: require('./lib/configRouter'),
  lessCompiler: require('./lib/lessCompiler'),
  run: function() { require('./lib/protoduction') }
}

