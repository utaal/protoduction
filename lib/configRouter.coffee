fs = require('fs')
jsonpath = require('JSONPath').eval
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

# match = (req, routes, i) ->
#   captures = undefined
#   method = req.method
#   i = i or 0
#   method = "GET"  if "HEAD" is method
#   if routes = routes[method]
#     url = parse(req.url)
#     pathname = url.pathname
#     len = routes.length
# 
#     while i < len
#       route = routes[i]
#       fn = route.fn
#       path = route.path
#       keys = fn.keys = route.keys
#       if captures = path.exec(pathname)
#         fn.params = []
#         j = 1
#         len = captures.length
# 
#         while j < len
#           key = keys[j - 1]
#           val = (if typeof captures[j] is "string" then decodeURIComponent(captures[j]) else captures[j])
#           if key
#             fn.params[key] = val
#           else
#             fn.params.push val
#           ++j
#         req._route_index = i
#         return fn
#       ++i

module.exports = (spec, cb) ->
  spec = spec || {}
  
  config_path = spec.config_path || config_path
  util.inspect(config_path)

  routes = []

  updateRoutes = (cb) ->
    data = fs.readFile config_path, 'utf8', (err, data) ->
      throw err if err
      new_routes = []
      lines = data.split("\n")
      _.each lines, (line) ->
        split = _.reject line.split(' '), (val) -> val == ""
        if split.length != 4
          return
        [path, template, data, jpath] = split
        new_routes.push
          path: normalizePath(path)
          template: template
          data_file: data
          jpath: jpath
      console.log new_routes
      routes = new_routes
      cb() if cb?

  getData = (data_file, jpath, cb) ->
    fs.readFile data_file, 'utf8', (err, data) ->
      if err
        cb(err)
        return
      try
        data = JSON.parse(data)
        data = jsonpath(data, jpath)
        console.log data
        cb null, data
      catch except
        err = {}
        err.message = except.message
        cb err

  processRequest = (req, res, next) ->
    get = req.method == 'GET'
    path = req.url
    found = false
    _.each routes, (route) ->
      console.log 'matching ' + route.path
      if captures = route.path.exec(path)
        console.log 'matched'
        found = true
        getData route.data_file, route.jpath, (err, obj) ->
          if err
            console.log err.message
            res.statusCode = 500
            res.end()
            return
          renderer.render route.template, obj[0], (err, html) ->
            if err
              console.log err.message
              res.statusCode = 500
              res.end()
              return
            res.end html
    next() if not found

  updateRoutes(cb)

  fs.watchFile config_path, (curr, prev) ->
    updateRoutes()

  return processRequest

