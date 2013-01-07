###
# protoduction responseCache module


This module provides in-memory caching of generated responses.
###

Cache = require('./connectCache.js')
connect = require('connect')

module.exports = (cache_size) ->
  cache = new Cache(cache_size || 0)

  obj =
    maybeHandleRequest : (key, req, res) ->
      hit = cache.get key
      if hit?
        responseHeaders = connect.utils.merge({}, hit.headers)
        ifModifiedSince = req.headers['if-modified-since']
        isFreshConditional = (connect.utils.conditionalGET(req) &&
                              ifModifiedSince &&
                              (new Date(ifModifiedSince) - hit.createdAt > -1000))
        if isFreshConditional?
          responseHeaders['content-length'] = 0
          res.writeHead(304, responseHeaders)
          res.end()
          return
        else
          res.writeHead(200, responseHeaders)
          res.write(hit.body)
          res.end()
          return
    addAndSend : (key, headers, body, res) ->
      cacheItem = cache.add key
      headers = connect.utils.merge({
        'Cache-Control': 'public, max-age=0, must-revalidate',
        'Last-Modified': '' + new Date()
      }, headers)
      cacheItem.headers = headers
      cacheItem.body = body
      res.writeHead 200, headers
      res.end body

  return obj

