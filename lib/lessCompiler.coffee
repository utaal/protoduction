fs = require('fs')
less = require('less')
log = require('./log').logger('lessCompiler')
url = require('url')

module.exports = (search_path, opts) ->
  opts = opts || {}
  compress = opts.compress || false

  ret = (req, res, next) ->
    parsedUrl = url.parse(req.url)
    path = parsedUrl.pathname
    if not path.substring(-4) == '.css'
      log.DEBUG "skipping #{path}, it doesn't end with .css"
      next()
      return
    if ~path.indexOf('..')
      log.DEBUG "skipping #{path}, contains unsafe parent directory .."
      next()
      return

    filename = search_path + path.substring(0, path.length - 4) + ".less"
    log.DEBUG "using template #{filename}"
    fs.readFile filename, 'utf8', (err, data) ->
      if err
        log.DEBUG "#{filename}: template not found"
        next()
        return
      lessParser = new less.Parser paths: [search_path], filename: filename
      lessParser.parse data, (err, tree) ->
        if err
          log.ERROR "#{filename}: cannot parse less: #{err}"
          err = new Error(http.STATUS_CODES[500])
          err.status = 500
          next err
          return
        try
          rendered = tree.toCSS compress: compress
        catch except
          log.ERROR "#{filename}: cannot render less: #{except.message}"
          err = new Error(http.STATUS_CODES[500])
          err.status = 500
          next err
          return
        res.writeHead 200, 'Content-Type': 'text/css'
        res.end rendered

