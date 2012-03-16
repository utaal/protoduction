module.exports = (log) ->
  httpError = (code, msg) ->
    log.ERROR "" + code + ': ' + msg
    err = new Error("" + msg)
    err.status = code
    err
  {
    httpError: httpError
  }
