###
# protoduction lessCompiler module

Compiles and serves less files.
###

connect = require('connect')
fs = require('fs')
less = require('less')
log = require('./log').logger('lessCompiler')
{ httpError } = require('./httpUtil')(log)
responseCache = require('./responseCache')
url = require('url')
util = require('util')

module.exports = (search_path, opts) ->
  opts = opts || {}
  compress = opts.compress || false

  log.DEBUG "cache size: " + opts.cache_size
  cache = responseCache(opts.cache_size)

  ret = (req, res, next) ->
    parsedUrl = url.parse(req.url)
    path = parsedUrl.pathname

    if path.substring(path.length - 4) != '.css'
      log.DEBUG "skipping #{path}, it doesn't end with .css"
      next()
      return
    if ~path.indexOf('..')
      log.DEBUG "skipping #{path}, contains unsafe parent directory .."
      next()
      return

    filename = search_path + path.substring(0, path.length - 4) + ".less"
    if cache.maybeHandleRequest filename, req, res
      return

    log.DEBUG "using template #{filename}"
    fs.readFile filename, 'utf8', (err, data) ->
      if err
        log.DEBUG "#{filename}: template not found"
        next()
        return
      lessParser = new less.Parser paths: [search_path], filename: filename
      lessParser.parse data, (err, tree) ->
        if err
          next httpError 500, "#{filename}: cannot parse less: #{err.message}"
          return
        try
          rendered = tree.toCSS compress: compress
        catch except
          next httpError 500, "#{filename}: cannot render less: #{except.message}"
          return

        headers =
          'Content-Type': 'text/css',
        cache.addAndSend filename, headers, rendered, res

