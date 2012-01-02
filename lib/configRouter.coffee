fs = require('fs')
http = require('http')
jsonpath = require('JSONPath').eval
log = require('./log').logger('configRouter')
renderer = require('./renderer')
util = require('util')
_ = require('underscore')

normalizePath = (path, keys) ->
  path = path.concat("/?")
  path = path.replace(/\/\(/g, "(?:/")
  path = path.replace /(\/)?(\.)?:(\w+)(?:(\(.*?\)))?(\?)?/g, (_, slash, format, key, capture, optional) ->
    keys.push key
    slash = slash or ""
    "" \
    + (if optional then "" else slash) \
    + "(?:" + (if optional then slash else "") \
    + (format or "") \
    + (capture or "([^/]+?)") \
    + ")" \
    + (optional or "")
  path = path.replace(/([\/.])/g, "\\$1")
  path = path.replace(/\*/g, "(.+)")
  new RegExp("^" + path + "$", "i")

httpError = (code) ->
  err = new Error(http.STATUS_CODES[code])
  err.status = code
  err

module.exports = (spec, cb) ->
  spec = spec || {}
  
  config_path = spec.config_path || 'config'
  util.inspect(config_path)

  routes = []

  updateRoutes = (cb) ->
    log.DEBUG "config_path: #{config_path}"
    data = fs.readFile config_path, 'utf8', (err, data) ->
      log.FATAL err if err
      new_routes = []
      lines = data.split("\n")
      _.each lines, (line) ->
        split = _.reject line.split(' '), (val) -> val == ""
        if split.length != 4
          return
        [path, template, data, jpath] = split
        keys = []
        path = normalizePath path, keys
        new_routes.push
          path: path
          keys: keys
          template: template
          data_file: data
          jpath: jpath
      log.DEBUG "loaded new routes"
      routes = new_routes
      cb() if cb?

  getData = (data_file, jpath, cb) ->
    fs.readFile data_file, 'utf8', (err, data) ->
      if err
        log.ERROR err
        cb httpError(404)
        return
      try
        data = JSON.parse(data)
        data = jsonpath(data, jpath)
        cb null, data
      catch except
        log.ERROR err
        cb httpError(500)

  match = (path) ->
    found = undefined
    i = 0
    while i < routes.length and not found?
      route = routes[i]
      log.DEBUG route
      if captures = route.path.exec(path)
        log.DEBUG captures
        params = []
        keys = route.keys
        j = 1
        len = captures.length

        while j < len
          key = keys[j - 1]
          val = (if typeof captures[j] is "string" then decodeURIComponent(captures[j]) else captures[j])
          if key
            params[key] = val
          else
            params.push val
          ++j

        jpath = route.jpath
        log.DEBUG 'keys: ' + keys
        jpath = jpath.replace '#' + key, params[key] for key in keys
        
        found =
          template: route.template
          data_file: route.data_file
          jpath: jpath
          keys: keys
          params: params
        log.DEBUG util.inspect(found)
      ++i
    return found

  processRequest = (req, res, next) ->
    get = req.method == 'GET'
    if not get
      next()
      return
    path = req.url
    matched = match path
    if not matched?
      log.DEBUG "url #{path} not matched"
      next()
      return
    getData matched.data_file, matched.jpath, (err, obj) ->
      if err
        next err
        return
      renderer.render matched.template, obj[0], (err, html) ->
        if err
          log.ERROR err
          next httpError(500)
          return
        res.end html

  updateRoutes(cb)

  fs.watchFile config_path, (curr, prev) ->
    if curr.mtime is not prev.mtime
      updateRoutes()

  return processRequest

