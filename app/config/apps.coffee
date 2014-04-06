express = require "express"
csrf = express.csrf()
assets = require "connect-assets"
flash = require "connect-flash"
RedisStore = require("connect-redis")(express)
blade = require "blade"
i18n = require "i18next"
logger = require "winston"
passport = require "passport"
LocalStrategy = require("passport-local").Strategy
cldr = require "cldr"
fs = require "fs"
__ = require "underscore"
device  = require "express-device"

thirdParty = ["google","yahoo","persona"]
if process.env.FB_APP_ID? and  process.env.FB_APP_SEC?
  thirdParty.push("facebook")
# if process.env.TT_APP_ID? and process.env.TT_APP_SEC?
#   thirdParty.push("twitter")
if process.env.GITHUB_ID? and process.env.GITHUB_SEC?
  thirdParty.push("github")
if process.env.LI_APP_ID? and process.env.LI_APP_SEC?
  thirdParty.push("linkedin")

logCategory = "CONFIGURE"
maxAges = 86400000 * 30

config = require "../config/config"
config.setEnvironment process.env.NODE_ENV or "development"
redisService =  process.env.REDISTOGO_URL || process.env.REDISCLOUD_URL
# Redis session stores
rediska = (if redisService? then require("redis-url").connect(redisService) else require("redis").createClient())

options =
  key: "blade-connect.sid"
  secret: "f2e5a67d388ff2090dj7Q2nC53pF"
  cookie:
    maxAge: 86400000 * 1 # 30 days

options.session_secret = options.secret

unless redisService
  options.hosts = [new RedisStore(
    hostname: config.REDIS_DB.hostname
    host: config.REDIS_DB.host
    port: config.REDIS_DB.port
    name: config.REDIS_DB.name
    password: config.REDIS_DB.password
    maxAge: config.REDIS_DB.maxAge # 30 days
  ), new RedisStore(
    hostname: config.REDIS_DB.hostname
    host: config.REDIS_DB.host
    port: config.REDIS_DB.port
    name: config.REDIS_DB.name
    password: config.REDIS_DB.password
    maxAge: config.REDIS_DB.maxAge # 30 days
  )]
else
  options.hosts = [new RedisStore(
    client: rediska
  ),new RedisStore(
    client: rediska
  )]

module.exports = (app) ->
  i18n.init(config.I18N)
  i18n.registerAppHelper(app)
  logger.info "Configure expressjs", logCategory
  # FIXME use _.each to loop for each dirs and Gzip
  #dirs = ["/assets", "/public", "/locales", "/data/topo"]

  app.configure ->
    app.use assets({ src : 'public'  })
    .use(express.favicon(process.cwd() + "/public/images/favicon.ico", {maxAge:maxAges}))
    .use(express.compress())
    .use(device.capture())
    .use(express.static(process.cwd() + "/public", {maxAge:maxAges}))
    .use('/font', express.static(process.cwd() + "/public/css/font", {maxAge:maxAges}))
    .use('/fonts', express.static(process.cwd() + "/public/css/fonts", {maxAge:maxAges}))
    .use(express.static(process.cwd() + "/js", {maxAge:maxAges}))
    .use(express.static(process.cwd() + "/locales", {maxAge:maxAges}))
    .use(express.static(process.cwd() + "/data/topo", {maxAge:maxAges}))
    .use(express.logger("dev"))
    .use(express.errorHandler(
      dumpException: true
      showStack: true
    ))
  #  Add template engine
  app.configure ->
    @set("views", process.cwd() + "/views")
    .set("view engine", "blade")
    #.use(stylus.middleware(
    #  src: process.cwd() + "/assets"
    #  compile: compile
    #))
  app.configure ->
    try
      require ("./passport.coffee")
      fs.readdir "./locales", (err,locales) ->
        EXCLUDE = [ "dev", "README.md", "config.json", "translations" ]
        languages = []
        results = __.reject locales, (value, index, list) ->
          return EXCLUDE.indexOf(value) != -1
        locales = __.each results, (value, index, list) ->
          locale = value.split("-")[0]
          language = cldr.extractLanguageDisplayNames(locale)[locale]
          languages[value] = language
        app.set "languages", languages
        #console.log locales
        results = []
        __.reject locales, (value, index, list) ->
          console.log value, index, list
          results.push value
        #console.log results
    catch e
      logger.warn "files not found " + e, logCategory
      require ("./passport.coffee")
      #app.set("chapters", [])
      app.set "languages", []
      #app.set "translation", []
      next()
      return

  multipleRedisSessions = require("connect-multi-redis")(app, express.session)
  # Set sessions and middleware
  app.configure ->
    @use(i18n.handle)
    .use(express.urlencoded())
    #.use(cors)
    .use(express.json())
    .use(express.methodOverride())
    .use(express.cookieParser("90dj7Q2nC53pFj2b0fa81a3f663fd64"))
    .use(multipleRedisSessions(options))

    options.key = "blade-connect.sid"
    options.store = options.hosts[0]
    options.cookie.maxAge = 86400000 * 30 #90 days

    @set 'sessionOptions', options

    @use(express.session(options))
    .use(passport.initialize())
    .use(passport.session())
    .use(blade.middleware(process.cwd() + "/views"))
    .use(express.csrf())
    #Configure dynamic helpers
    .use (req, res, next) ->
      formData = req.session.formData or {}
      code = i18n.lng().substr(0, 2)
      delete req.session.formData
      res.locals
        #for use in templates
        appName: config.APP.name
        #for connect-flash
        messages: req.flash("info")
        # needed for csrf support
        csrf_token: req.csrfToken()
        #language
        lang: code
        #socials
        socials: thirdParty
        #user
        user: req.user
        # res.cookie.
        device: req.device.type
      next()
    app
