util = require('util')
connect = require('connect')
request = require('../support/http')

app = connect()

describe 'configrouter', () ->

  configRouterModule = require('../../lib/configRouter')
  configRouter = undefined

  it 'should load correctly', (done) ->
    configRouter = configRouterModule config_path: 'test/fixtures/config', done
    app.use(configRouter)

  it 'should process requests', (done) ->
    console.log util.inspect(app)
    request(app)
      .get('/')
      .expect(200, done)



