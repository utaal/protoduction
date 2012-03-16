###
# protoduction renderer module

Jade templates rendering helper
###

fs = require('fs')
jade = require('jade')

compile = (template_path, cb) ->
  ###
  Compile a template file
  ###

  fs.readFile template_path, 'utf8', (err, data) ->
    if (err)
      cb err
      return
    try
      fn = jade.compile data, filename: template_path
      cb null, fn
    catch except
      err = {}
      err.message = "#{template_path}: invalid jade file: #{except.message}"
      cb(err)

render = (template_path, locals, cb) ->
  ###
  Render a jade template with the provided locals.
  ###
  compile template_path, (err, fn) ->
    if (err)
      cb err
      return
    try
      rendered = fn(locals)
      cb null, rendered
    catch except
      err = {}
      err.message = "#{template_path}: cannot render jade: #{except.message}"
      cb err


module.exports =
  compile: compile
  render: render
