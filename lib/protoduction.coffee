###
# Protoduction entry point
###

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
  .default('data-path', 'data.yml')
  .boolean('help')
  .default('minify-css', true) # TODO: use NODE_ENV instead
  .default('public-path', 'public')
  .default('stylesheet-path', 'style')

argv = optimist.argv
if argv.help
  optimist.showHelp()
  return

if argv.debug
  logmodule.enableDebug()

log = logmodule.logger('protoduction')
log.DEBUG __dirname

server = connect.createServer()
server.use connect.logger('tiny')
server.use connect.staticCache()
server.use connect.static(argv['public-path'])
server.use '/' + argv['stylesheet-path'], lessCompiler(
  argv['stylesheet-path'],
  {compress: argv['minify-css']})
server.use configRouter(argv['config-path'], argv['data-path'])

server.listen(argv.port)
log.INFO "serving on port #{argv.port}"
