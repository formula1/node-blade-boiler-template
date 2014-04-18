### Routes
# We are setting up these routes:
#
# GET, POST, PUT, DELETE methods are going to the same controller methods - we dont care.
# We are using method names to determine controller actions for clearness.
###
fs = require 'fs'
authentication = require "../authentication"
module.exports = (app) ->
  #   - _/_ -> controllers/index/index method
  app.all "/", (req, res, next) ->
    routeMvc("index", "index", req, res, next)
  authentication.routes(app)
  fs.readdirSync(process.cwd() + "/app/controllers").forEach (file) ->
    controller = file.split(".")[0]
    app.all "/#{controller}", (req, res, next) ->
      routeMvc("#{controller}", "index", req, res, next)
  #   - _/**:controller**_  -> controllers/***:controller***/index method
  app.all "/:controller", (req, res, next) ->
    routeMvc(req.params.controller, "index", req, res, next)
  #   - _/**:controller**/**:method**_ -> controllers/***:controller***/***:method*** method
  app.all /\controller?\/(locales|js|translation)/, (req, res, next) ->
    routeJSON(req, res, next)
  app.all "/:controller/:method", (req, res, next) ->
    routeMvc(req.params.controller, req.params.method, req, res, next)
  #   - _/**:controller**/**:method**/**:id**_ -> controllers/***:controller***/***:method*** method with ***:id*** param passed
  app.all "/:controller/:method/:id", (req, res, next) ->
    routeMvc(req.params.controller, req.params.method, req, res, next)
  # Robots.txt
  app.all '/robots.txt', (req, res) ->
    req.flash()
    res.set 'Content-Type', 'text/plain'
    if app.settings.env == 'production'
      res.send 'User-agent: *\nDisallow: /signin\nDisallow: /signup\n
          Disallow: /signout\nSitemap: /sitemap.xml'
    else
      res.send 'User-agent: *\nDisallow: /'
  # If all else failed, show 404 page
  app.all "*", (req, res) ->
    res.status(404).render '404'

# render the page based on controller name, method and id
routeMvc = (controllerName, methodName, req, res, next) ->
  controllerName = "index" if not controllerName?
  controller = null
  try
    controller = require "../controllers/" + controllerName
  catch e
    console.warn "controller not found:  " + controllerName, e
    console.log(controllerName, methodName)
    next()
    return
  data = null
  console.log(controller[methodName])
  if typeof controller[methodName] is "function"
    actionMethod = controller[methodName].bind controller
    actionMethod req, res, next
  else if typeof controller["all"] is "function"
    actionMethod = controller["all"].bind controller
    actionMethod req, res, next
  else
    console.warn "method not found: " + methodName
    next()

# render the locale json and js
routeJSON = (req, res, next) ->
  console.log "XXX"
  next()
