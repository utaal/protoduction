var connect = require('connect');
var console = require('console');
var fs = require('fs');
var jade = require('jade');
var less = require('less');
var argv = require('optimist')
  .default('port', 8000)
  .boolean('nohtmlcache')
  .boolean('nocsscache')
  .boolean('nocache')
  .boolean('nocompress')
  .boolean('accesslog')
  .argv;

Function.prototype.curry = function() {
  var fn = this, args = Array.prototype.slice.call(arguments);
  return function() {
    return fn.apply(this, args.concat(
      Array.prototype.slice.call(arguments)));
  };
};

function error(msg) {
  console.log('[ERROR] ' + msg);
}

function info(msg) {
  console.log('[INFO] ' + msg);
}

var css_cache = {}
function less_do(stylesheet, cb) {
  var rendered = css_cache[stylesheet];
  if (rendered) {
    cb(null, rendered);
  } else {
    var filename = stylesheet + '.less';
    info('"' + filename + '": compiling less');

    var parser = new(less.Parser)({
      paths: ['.'],
      filename: filename
    });

    fs.readFile(filename, 'ascii', function(err, data) {
      if (err) {
        cb(err);
        return;
      }
      console.log('>' + typeof(data));
      parser.parse(data, function(err, tree) {
        if (err) {
          cb(err);
          return;
        }
        console.log('>' + tree);
        rendered = tree.toCSS({ compress: !argv.nocompress }); 
        info('"' + filename + '": less rendered, caching (if not disabled)');
        css_cache[stylesheet] = rendered;
        cb(null, rendered);
      });
    });
  }
}

var jade_compiled = {}
function jade_do(template, locals, cb) {
  var fn = jade_compiled[template];
  if (argv.nohtmlcache || ! fn) {
    var filename = template + '.jade';
    info('"' + filename + '": compiling jade');
    fs.readFile(filename, 'ascii', function(err, data) {
      if (err) {
        cb(err, null);
        return;
      }
      fn = jade.compile(data, { filename: filename });
      info('"' + filename + '": jade complied, caching (if not disabled)');
      jade_compiled[template] = fn;
      try {
        var rendered = fn(locals);
        cb(null, rendered);
      } catch (e) {
        err = {}; 
        err.message = '"' + filename + '": invalid jade file: ' + e.message;
        cb(err);
      }
    });
  } else { // cached
    cb(null, fn(locals));
  }
}

function data_cb_for_content_type(content_type, res, err, data) {
  if (err) {
    if (err.code == 'ENOENT') {
      res.statusCode = 404;
    } else {
      error(err.message);
      res.statusCode = 500;
    }
    res.end();
    return;
  }
  res.writeHead(200, {'Content-Type': content_type});
  res.end(data);
}

function less_handler(req, res, next) {
  less_do(
      req.params.stylesheet,
      data_cb_for_content_type.curry('text/css', res));
}

function jade_handler(req, res, next) {
  var data_cb = data_cb_for_content_type.curry('text/html', res);
  if (! req.params.page) {
    jade_do('index', {}, data_cb); 
  } else {
    jade_do(req.params.page, {}, data_cb);
  }
}

var routes = function(app) {
  app.get('/:stylesheet.less', less_handler);
  app.get('/:page', jade_handler);
  app.get('/', jade_handler);
}

var server = connect.createServer(
    connect.logger('tiny')
  , connect.static(__dirname + '/static')
  , connect.router(routes)
    );

if (argv.nocache) {
  argv.nohtmlcache = argv.nocsscache = true;
}

server.listen(argv.port);
info('serving on port ' + argv.port);
