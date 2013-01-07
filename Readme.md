# Protoduction
    Copyright (c) 2012 Andrea Lattuada, MIT licensed (see LICENSE)

Want an easy and fast way to create a static blog/site, keep control of your html and css,
avoid evil CMSes and still be DRY?

Enter **protoduction**,
a simple, configurable server for template-based static websites
built on [node](http://nodejs.org) as a [Connect](http://github.com/senchalabs/connect) middleware.

- It lets you keep your *backing data* in [YAML](http://yaml.org/) files, completely separate from presentation,
- filter it based on request path, through [JSONPath](http://goessner.net/articles/JsonPath/)
- and present it in beautifully logic-less [jade](http://jade-lang.com/) templates.

## Installation

Make sure you have [node](http://nodejs.org) 0.6.x installed, then run

    npm install -g protoduction

[npm](http://npmjs.org/) is node's package manager.

## A protoduction site

A protoduction site is, by default, represented by a directory containing,
at least, a single config file named `config` and a root data file named `data.yml`.

`config` is a list of routes, each one with 2 to 4 parameters, separated by newlines, e.g.

    /               index.jade           $.index
    /posts/:id      blog_post.jade       $.posts['#id']      one
    /pages/:pageid  pages/#pageid.jade   $.pages['#pageid']  one

where the parameters represent, respectively (in parentheses the corresponding actual argument for the second route in the example `config`) 

- (`/posts/:id`) is the route to be matched, may contain route parameters (like `:id`); more complex matching is possible as explained
later in this readme
- (`index.jade`) is the template to be rendered in response
- (`$.index`) is a JSONPath query on the root object of the backing data file: the matched object(s) will be passed as view data (argument) to the jade template
- an optional last argument (only allowed when data path specified) may be one of:
  - `one`: proceed rendering only if one and only one match is returned from the JSONPath query, pass that object as the view data
  - `any`: proceed rendering anyway, pass an array containing the matches (possibly none or multiple)
  - `many`: same as `any`, but proceed rendering only if at least one object is returned
  - if no option is specified: proceed rendering anyway, pass only the first match (or `null` if not present) as view data

The JSONPath expressions and template paths may contain `#` (hashes) followed by the name of a route parameter (e.g. `$.posts['#id'] where `id` refers to `:id` in `/posts/:id`): they will be substitued with their actual value in the current request path before the evaluation of the JSONPath expression against it.

Jade templates get passed the matched object from backing data with two fileds added:
  - `context` contain the entire contents of the data file
  - `params` contain the values of the route parameters in the current request

Routes are [sinatra](http://www.sinatrarb.com/intro#Routes) -like, or similarly, [connect.router](http://senchalabs.github.com/connect/middleware-router.html) -like, in fact the routing implementation is a modified version of connect.router's route matching function.

The yaml parser is equipped with a custom type constructor, `!include`, that allows the inclusion of other yaml files in place of elements: you can say `!include other_data_file.yml` and it will be replaced with the other_data_file contents at the same indentation level.

An example site showcasing most of the available features can be found in `example/`.

By default, two subdirs of the root protoduction site directories are treated
specially:

    /style/           <- .less files inside here will be rendered and served as /style/*.css
                           e.g. /style/main_style.less will be accessible at
                                /style/main_style.css

    /public/          <- static public files go here (e.g. favicon.ico)
                           they will be served at the site root
                           e.g. /public/favicon.ico
                           they take precedece over configured routes

## Testing and deploying the site

While devloping, just run `protoduction` (installed in your $PATH by npm -g) at the root directory of the protoduction site,
options available as listed by `protoduction --help`.
All data files, jade/less templates and static resources are checked/rerendered/reloaded on every request so you can iterate
quickly. A restart is only needed after a change to the `config` file so that protoduction can pick up the new routes.

When **deploying**, install protoduction on the target machine, copy the site directory to the production machine and, at its root, run

    NODE_ENV='production' protoduction --port 8000 # or whatever port you like

Starting with `NODE_ENV='production'` will disable developer-oriented error output in the browser and enable caching (LRU) of rendered css and jade. The number of most requested items that will be kept in cache can be tweaked with `--less-cache-size` and `--page-cache-size`. When server-side caching is enabled, protoduction will also honor if-modified-since conditional GETs and will return a 304 (Not Modified) status code for all requests whose target has been cached since the last server restart. For these reasons the server should be restarted after any change to the site definition in production.

It's recommended to run protoduction on a nonprivileged port behind a reverse proxy (as nginx, apahe with mod_proxy or node-proxy) running on port 80.

Keep in mind that while pretty simple, this is *really* young code, it may fail in the most unexpected ways. And I won't be held responsible for that, while I'll try my best to get it fixed for you (send a bug report!).

TIP: use git hooks for automated deployments, [monit](http://mmonit.com/monit/) or to keep it up even if it fails miserably, and [upstart](http://upstart.ubuntu.com/) or the like to make it restart automatically on reboot

TIP: if you'd like to use [forever](https://github.com/nodejitsu/forever) or similar node-specific tools instead, save this simple script as `server.js` on the website root

    var protoduction = require('protoduction');
    protoduction.run();

so you can launch it with `node server.js`, `forever server.js`, etc.
This allows you to install protoduction locally instead of globally (as you won't need the protoduction binary anymore).

## Contributions / Bugs

Contributions are welcome! as well as bug reports and feature requests. 

Use github issues/pullrequests, or send me an email: andrea [at] backyardscale [dot] com

Testing is done through the excellent and extra-fun [mocha](http://visionmedia.github.com/mocha/), just run

    npm test

### TODO

- configuration DSL in CoffeeScript

#### Author: [Andrea Lattuada](http://utaal.github.com)
