express = require "express"
RedisStore = require("connect-redis")(express)
i18next = require "i18next"
connectAssets = require "connect-assets"
connectFlash = require "connect-flash"
blade = require "blade"
expressDevice  = require "express-device"
cldr = require "cldr"
fs = require "fs"
logger = require "winston"
passport = require "passport"
__ = require "underscore"
expressDevice  = require "express-device"

########### initialize passport strategies ######################################
require "./passport.coffee"

########### find out supported social websites ##################################
socials = ["google","yahoo","persona"]
if process.env.FB_APP_ID? and  process.env.FB_APP_SEC? then socials.push("facebook")
if process.env.GITHUB_ID? and process.env.GITHUB_SEC? then socials.push("github")
if process.env.LI_APP_ID? and process.env.LI_APP_SEC? then socials.push("linkedin")

############ init config #########################################################
config = require "../config/config"
config.setEnvironment process.env.NODE_ENV or "development"

############ session setup #######################################################
sessionOptions =
  #express-session options
  key: "blade-connect.sid"
  secret: "f2e5a67d388ff2090dj7Q2nC53pF"
  cookie:
    maxAge: 86400000 * 30 # 30 days
  store: new RedisStore()

############ set view locals #####################################################
setViewLocals = (req, res, next) ->
  res.locals
    appName: config.APP.name
    messages: req.flash("info")      #for connect-flash
    csrf_token: req.csrfToken()      #needed for csrf support
    lang: i18next.lng().substr(0, 2) #language
    socials: socials
    user: req.user                   #user
    device: req.device.type          #device type
  next()

############ scan for available languages ###########################################
getAvailableLanguages = ->
  excludeFiles = [ "dev", "README.md", "config.json", "translations" ]
  files = fs.readdirSync "./locales"
  langDirs = __.difference(files, excludeFiles)
  allLangs = {}
  __(langDirs).each (dirName) ->
      langCode = dirName.split("-")[0]
      allLangs[dirName] = cldr.extractLanguageDisplayNames(langCode)[langCode]
  allLangs

############ app setup ##############################################################
module.exports = (app) ->
  logger.info "Configure expressjs", "CONFIGURE"
  maxAgesOption = { maxAge: 86400000 * 30 }
  
  i18next.init(config.I18N)
  i18next.registerAppHelper(app)

  app
  .use connectAssets({ src : 'public'  })
  .use( express.favicon("public/images/favicon.ico", maxAgesOption) )
  .use( express.static("public", maxAgesOption) )
  .use( express.static( "js", maxAgesOption) )
  .use( express.static( "locales", maxAgesOption) )
  .use( express.static( "data/topo", maxAgesOption) )
  .use( express.compress() )
  .use( express.urlencoded() )
  .use( express.json() )
  .use( express.methodOverride() )
  .use( express.cookieParser("90dj7Q2nC53pFj2b0fa81a3f663fd64") )
  .use( express.session(sessionOptions) )
  .use( passport.initialize() )
  .use( passport.session() )
  .use( express.logger("dev") )
  .use( express.errorHandler( { dumpException: true,  showStack: true } ) )
  .use( i18next.handle )
  .use( express.csrf() )
  .use( connectFlash() )
  .use( expressDevice.capture() )
  .use( setViewLocals )
  .use( expressDevice.capture() )
  .use( blade.middleware("views") )
  .set( "sessionOptions", sessionOptions ) #used by engine.io
  .set( "view engine", "blade" )
  .set( "languages", getAvailableLanguages() )
  app
