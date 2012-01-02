should = require('should')
util = require('util')

describe 'renderer', ->
  renderer = require('../../lib/renderer')

  it 'should compile jade', (done) ->
    renderer.compile 'test/fixtures/template.jade', (err, data) ->
      should.not.exist(err)
      data.should.be.a('function')
      done()

  TEXT = 'test'

  it 'should render jade', (done) ->
    renderer.render 'test/fixtures/template.jade', { text: TEXT }, (err, data) ->
      console.log(data)
      should.not.exist(err)
      data.should.be.a('string')
      EXPECTED = """<html><head><title>a</title></head><body>test 
</body></html>"""
      data.should.equal(EXPECTED)
      done()

