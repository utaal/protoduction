###
# protoduction configRouter module


This module parses the route config file and acts as a connect middleware to serve requests.
###

fs = require('fs')
http = require('http')
jsonpath = require('JSONPath').eval
log = require('./log').logger('configRouter')
{ httpError } = require('./httpUtil')(log)
renderer = require('./renderer')
url = require('url')
util = require('util')
_ = require('underscore')


normalizePath = (path, keys) ->
  ###
  Normalizes and converts a sinatra-like route and transforms it to an equivalent regular expression.
  The 'keys' parameter should be an empty array and will be filled with the names of path parameters (:param) encountered.
  ###

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


module.exports = (config_path, data_path, cb) ->
  ###
  Exported higher order function which, provided with a config file path,
  returns a connect middleware.
  The optional callback is called as soon as first-time initialization is
  complete.
  ###
  
  if not config_path?
    throw new Error('Missing configuration file path (config_path)')
  if not data_path?
    throw new Error('Missing data file path (data_path)')

  routes = []
  data = {}

  # Route conditions allow conditional route processing based on the
  # number of object matched by the JSONPath query
  ROUTE_COND_ONE = 1
  ROUTE_COND_MULTI = 2
  ROUTE_COND_ALL = 3


  init = (cb) ->
    updateRoutes () ->
      updateData () ->
        cb() if cb?

    fs.watchFile config_path, (curr, prev) ->
      if curr.mtime.getTime() != prev.mtime.getTime()
        updateRoutes()
    fs.watchFile data_path, (curr, prev) ->
      if curr.mtime.getTime() != prev.mtime.getTime()
        updateData()


  parseConfigLine = (line) ->
    ###
    Parse a single config file line.
    ###

    split = _.reject line.split(/\s/), (val) -> val == ""
    if split.length < 2
      return
    [path, template, jpath, cond] = split
    keys = []
    path = normalizePath path, keys
    route =
      path: path
      keys: keys
      template: template
    if jpath?
      switch cond
        when "one" then cond = ROUTE_COND_ONE
        when "multi" then cond = ROUTE_COND_MULTI
        when "all" then cond = ROUTE_COND_ALL
        else cond = null
      route.jpath = jpath
      route.cond = cond
    route

  updateRoutes = (cb) ->
    ###
    (Re)loads the routing configuration from config_path.
    ###
 
    log.DEBUG "config_path: #{config_path}"
    fs.readFile config_path, 'utf8', (err, routedata) ->
      log.FATAL err if err
      lines = routedata.split("\n")
      parsed = _.map lines, (line) -> parseConfigLine line
      new_routes = _.filter parsed, (route) -> route?
      log.DEBUG "loaded new routes\n" + util.inspect new_routes
      routes = new_routes
      cb() if cb?



  updateData = (cb) ->
    ###
    (Re)loads data from data_path.
    ###
    
    fs.readFile data_path, 'utf8', (err, datafile) ->
      log.FATAL err if err
      log.DEBUG 'loading data file'
      try
        yaml = require('js-yaml')
        data = yaml.load(datafile)
        log.DEBUG 'loaded data: ' + util.inspect data
        cb() if cb?
      catch except
        log.FATAL 'cannot parse data file: ' + except
  
  getData = (jpath, cb) ->
    ###
    Retrieves data matching a given jsonpath.
    Callbacks when complete with the matched object(s) and the entire data file
    contents as context.
    ###

    try
      context = data
      matched = context
      if jpath == '$'
        if not (matched instanceof Array)
          matched = [matched]
      else
        matched = jsonpath(matched, jpath)
      log.DEBUG 'matched data: ' + util.inspect matched
      cb null, matched, context
    catch except
      cb httpError(500, except.message)


  mapPathParams = (path, params) ->
    if path?
      for key of params
        if ~params[key].indexOf('..')
          log.INFO "skipping #{key} param, contains unsafe parent directory .."
        else
          path = path.replace '#' + key, params[key]
    path


  tryRoute = (route, path) ->
    ###
    Attempts to match a single route to the request path.
    Returns the matched object and if the match was successful, null otherwise.
    ###

    log.DEBUG "trying route: " + util.inspect route
    captures = route.path.exec(path)
    if not captures?
      return null
    params = {}
    keys = route.keys
    j = 0
    captures = captures[1..captures.length]
    log.DEBUG "captures: " + util.inspect captures
    keyscapt = _.zip(keys, captures)
    _.each keyscapt, (kc) ->
      [key, capture] = kc
      val = if typeof capture is "string" \
        then decodeURIComponent(capture) else capture
      params[key] = val

    jpath = mapPathParams route.jpath, params
    template = mapPathParams route.template, params
    
    found =
      template: template
      jpath: jpath
      keys: keys
      params: params
      cond: route.cond
    log.DEBUG util.inspect(found)
    found


  match = (path) ->
    ###
    Matches a request path with the current route configuration.
    Returns the first matching route.
    ###

    found = undefined
    i = 0
    while i < routes.length and not found?
      route = routes[i]
      found = tryRoute route, path
      ++i
    return found


  send = (matched, obj, context, req, res, next) ->
    ###
    Renders and sends response.
    ###

    obj ||= {}
    obj.params = matched.params
    obj.context = context
    log.DEBUG 'rendering with object: ' + util.inspect obj
    renderer.render matched.template, obj, (err, html) ->
      if err
        next httpError 500, err.message
        return
      res.writeHead 200, 'Content-Type': 'text/html'
      res.end html


  processRequest = (req, res, next) ->
    ###
    Connect middleware returned by the exported function.
    ###

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
    if not matched.jpath?
      send matched, {}, data, req, res, next
    else
      getData matched.jpath, (err, obj, context) ->
        if err
          next httpError 500, err.message
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
        send matched, obj, context, req, res, next

  init(cb)
  return processRequest

