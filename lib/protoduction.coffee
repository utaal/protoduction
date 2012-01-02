connect = require('connect')
configRouter = require('./configRouter')
lessCompiler = require('./lessCompiler')
logmodule = require('./log')
util = require('util')

optimist = require('optimist')
  .usage('Start protoduction server\nUsage: $0')
  .default('port', 8000)
  .default('debug', false)
  .default('config-path', 'config')
  .boolean('help')
  .default('minify-css', true) # TODO: use NODE_ENV instead
  .default('static-path', 'static')
  .default('stylesheet-path', 'style')

argv = optimist.argv
if argv.help
  optimist.showHelp()
  return

if argv.debug
  logmodule.enableDebug()

log = logmodule.logger('protoduction')
log.DEBUG __dirname

server = connect.createServer(
  connect.logger('tiny'),
  connect.staticCache(),
  connect.static(argv['static-path']),
  lessCompiler(argv['stylesheet-path'], {compress: argv['minify-css']}),
  configRouter(argv['config-path'])
)

server.listen(argv.port)
log.INFO "serving on port #{argv.port}"
