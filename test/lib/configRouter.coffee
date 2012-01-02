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
    configRouter = configRouterModule 'test/fixtures/config', done
    app.use(configRouter)

  it 'should process requests', (done) ->
    request(app)
      .get('/')
      .expect(200, done)

  it 'should process parametrized routes', (done) ->
    request(app)
      .get('/testurl')
      .expect(200, done)

  it 'should ignore parametrized routes with condition "one" and empty data', (done) ->
    request(app)
      .get('/favicon.ico')
      .expect(404, done)

  it 'should pass params in view data', (done) ->
    request(app)
      .get('/withparams/12?text=test')
      .expect(200, done)
