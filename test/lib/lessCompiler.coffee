log = require('../../lib/log')
util = require('util')
connect = require('connect')
request = require('../support/http')

app = connect()

describe 'lessCompiler', () ->

  lessCompilerModule = require('../../lib/lessCompiler')
  log.test('lessCompiler')
  lessCompiler = undefined

  it 'should load correctly', () ->
    lessCompiler = lessCompilerModule 'test/fixtures'
    app.use(lessCompiler)

  it 'should render css', (done) ->
    request(app)
      .get('/test.css')
      .expect(200, done)

