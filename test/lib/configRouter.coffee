log = require('../../lib/log')
util = require('util')
connect = require('connect')
request = require('../support/http')

app = connect()

describe 'configrouter', () ->

  configRouterModule = require('../../lib/configRouter')
  log.test('configRouter')
  configRouter = undefined

  it 'should load correctly', (done) ->
    configRouter = configRouterModule config_path: 'test/fixtures/config', done
    app.use(configRouter)

  it 'should process requests', (done) ->
    request(app)
      .get('/')
      .expect(200, done)

  it 'should process parametrized routes', (done) ->
    request(app)
      .get('/testurl')
      .expect(200, done)
