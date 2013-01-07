###
# Protoduction entry point
###

connect = require('connect')
configRouter = require('./configRouter')
lessCompiler = require('./lessCompiler')
logmodule = require('./log')
send = require('send')
url = require('url')
util = require('util')

production = (process.env.NODE_ENV || '').toLowerCase() == 'production'

optimist = require('optimist')
  .usage('Start protoduction server\nUsage: $0')
  .default('port', 8000)
  .default('debug', false)
  .default('config-path', 'config')
  .default('data-path', 'data.yml')
  .boolean('help')
  .default('less-cache-size', if production then 10 else 0)
  .default('minify-css', production)
  .default('page-cache-size', if production then 10 else 0)
  .default('public-path', 'public')
  .default('stylesheet-path', 'style')


argv = optimist.argv
if argv.help
  optimist.showHelp()
  return

if argv.debug
  logmodule.enableDebug()

log = logmodule.logger('protoduction')
log.DEBUG "__dirname: #{__dirname}"

server = connect.createServer()
server.use connect.logger('tiny')
server.use '/', (req, res, next) ->
  send(req, url.parse(req.url).pathname).root(argv['public-path']).on('error', () -> next()).pipe(res)
server.use '/' + argv['stylesheet-path'], lessCompiler(
  argv['stylesheet-path'],
  {compress: argv['minify-css'], cache_size: argv['less-cache-size']})
server.use configRouter(argv['config-path'], argv['data-path'],
                        {cache_size: argv['page-cache-size']})
server.use (req, res, next) ->
  res.writeHead 404
  if !production
    res.write "Cannot #{req.method} #{url.parse(req.url).pathname}"
  res.end()
server.use (err, req, res, next) ->
  res.writeHead err.status
  if !production
    res.write "Protoduction: HTTP " + err.status + "\n\n"
    res.write err.message
  res.end()

server.listen(argv.port)
log.INFO "serving on port #{argv.port}"

