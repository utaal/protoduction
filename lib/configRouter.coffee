fs = require('fs')
http = require('http')
jsonpath = require('JSONPath').eval
log = require('./log').logger('configRouter')
renderer = require('./renderer')
url = require('url')
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

module.exports = (config_path, cb) ->
  
  if not config_path?
    throw new Error('Missing configuration file path (config_path)')

  routes = []

  ROUTE_COND_ONE = 1
  ROUTE_COND_MULTI = 2
  ROUTE_COND_ALL = 3

  updateRoutes = (cb) ->
    log.DEBUG "config_path: #{config_path}"
    data = fs.readFile config_path, 'utf8', (err, data) ->
      log.FATAL err if err
      new_routes = []
      lines = data.split("\n")
      _.each lines, (line) ->
        split = _.reject line.split(/\s/), (val) -> val == ""
        if split.length < 2
          return
        [path, template, data, jpath, cond] = split
        keys = []
        path = normalizePath path, keys
        route =
          path: path
          keys: keys
          template: template
        if data? and jpath?
          switch cond
            when "one" then cond = ROUTE_COND_ONE
            when "multi" then cond = ROUTE_COND_MULTI
            when "all" then cond = ROUTE_COND_ALL
            else cond = null
          route.data_file = data
          route.jpath = jpath
          route.cond = cond
        new_routes.push route
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
      log.DEBUG "route: " + util.inspect route
      if captures = route.path.exec(path)
        log.DEBUG "captures: " + util.inspect captures
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
        if jpath?
          jpath = jpath.replace '#' + key, params[key] for key in keys
        
        found =
          template: route.template
          data_file: route.data_file
          jpath: jpath
          keys: keys
          params: params
          cond: route.cond
        log.DEBUG util.inspect(found)
      ++i
    return found

  send = (matched, obj, req, res, next) ->
    obj.params = matched.params
    renderer.render matched.template, obj, (err, html) ->
      if err
        log.ERROR err
        next httpError(500)
        return
      res.writeHead 200, 'Content-Type': 'text/html'
      res.end html

  processRequest = (req, res, next) ->
    get = req.method == 'GET'
    if not get
      next()
      return
    parsedUrl = url.parse req.url
    matched = match parsedUrl.pathname
    if not matched?
      log.DEBUG "url #{parsedUrl.pathname} not matched"
      next()
      return
    if not matched.data_file?
      send matched, {}, req, res, next
    else
      getData matched.data_file, matched.jpath, (err, obj) ->
        if err
          log.ERROR err
          next httpError(500)
          return
        switch matched.cond
          when ROUTE_COND_ONE
            if obj.length != 1
              log.DEBUG "route condition 'one' not satisfied"
              next()
              return
            obj = obj[0]
          when ROUTE_COND_MULTI
            if obj.length < 1
              log.DEBUG "route condition 'multi' not satisfied"
              next()
          when ROUTE_COND_ALL
          else
            obj = obj[0]
        send matched, obj, req, res, next

  updateRoutes(cb)

  fs.watchFile config_path, (curr, prev) ->
    if curr.mtime.getTime() != prev.mtime.getTime()
      updateRoutes()

  return processRequest

