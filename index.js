require('coffee-script')
var log = require('log')

module.exports = {
  enableDebug: log.enableDebug,
  configRouter: require('./lib/configRouter'),
  lessCompiler: require('./lib/lessCompiler')
}

