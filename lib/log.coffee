testMode = []
debug = false

logger = (module) ->
  prefix = () ->
    if module in testMode
      "\n        "
    else
      ""
  ret =
    INFO: (message) ->
      console.info prefix() + "INFO  [#{module}] " + message
    ERROR: (message) ->
      msg = message
      msg = message.message if message? and message.message?
      console.error prefix() + "ERROR [#{module}] " + msg
    FATAL: (message) ->
      msg = message
      msg = message.message if message? and message.message?
      console.error prefix() + "FATAL [#{module}] " + msg
      process.exit(1)
    DEBUG: (message) ->
      if debug
        msg = message
        msg = message.message if message? and message.message?
        console.log prefix() + "DEBUG [#{module}] " + msg

test = (module) ->
  testMode.push module
  enableDebug()

enableDebug = () ->
  debug = true
  return this

module.exports =
  logger: logger,
  test: test
  enableDebug: enableDebug
