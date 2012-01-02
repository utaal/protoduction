connect = require('connect')
configRouter = require('./configRouter')
logmodule = require('./log')
util = require('util')

argv = require('optimist')
  .default('port', 8000)
  .default('debug', false)
  .default('config_path', 'config')
  .boolean('accesslog')
  .argv

if argv.debug
  logmodule.enableDebug()

log = logmodule.logger('protoduction')

server = connect.createServer(
  connect.logger('tiny'),
  connect.staticCache(),
  connect.static(__dirname + '/static'),
  configRouter(argv.config_path)
)

server.listen(argv.port)
log.INFO "serving on port #{argv.port}"
