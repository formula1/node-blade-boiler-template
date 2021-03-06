#### Config file
# Sets application config parameters depending on `env` name
db = require "./db"
exports.setEnvironment = (env) ->
  # General settings
  exports.SMTP =
    service: "Gmail"
    user: process.env.SMTP_USER
    pass: process.env.SMTP_PASSWD

  exports.EMAIL =
    registration: "dev@continentalclothing.com"
    info: "info@continentalclothing.com"


  uploads = exports.UPLOADS = 'uploads'
  cdn = exports.CDN = "cdn.continentalclothing.com"

  fs = require 'fs'
  try
    unless fs.existsSync uploads
      fs.mkdirSync uploads
      console.log 'created ' + uploads + ' folder'
  catch e
    console.log 'failed to create ' + uploads + ' folder'

  exports.PARSE_INTERVAL = 20000
  switch(env)
    when "development"
      exports.PORT = process.env.PORT or 3000
      exports.APP =
        name: "CCC Dev"
        hostname: process.env.HOSTNAME || "localhost"
        host: "127.0.0.1"
      exports.DEBUG_LOG = true
      exports.DEBUG_WARN = true
      exports.DEBUG_ERROR = true
      exports.DEBUG_CLIENT = true
      exports.REDIS_DB = db.redis
      exports.MONGO_DB_URL = db.mongo.MONGO_DB_URL
    when "test"
      exports.PORT = process.env.PORT or 3000
      exports.APP =
        name: "CCC Test"
        hostname: process.env.HOSTNAME || "localhost"
        host: "127.0.0.1"
      exports.DEBUG_LOG = false
      exports.DEBUG_WARN = false
      exports.DEBUG_ERROR = true
      exports.DEBUG_CLIENT = true
      exports.REDIS_DB = db.redis
      exports.MONGO_DB_URL = db.mongo.MONGO_DB_URL
    when "production"
      exports.PORT = process.env.PORT or process.env.VMC_APP_PORT or process.env.VCAP_APP_PORT
      exports.APP =
        name: "CCC"
        hostname: process.env.HOSTNAME || "www.continentalclothing.com"
      exports.DEBUG_LOG = false
      exports.DEBUG_WARN = false
      exports.DEBUG_ERROR = true
      exports.DEBUG_CLIENT = false
      exports.REDIS_DB = db.redis
      exports.MONGO_DB_URL = db.mongo.MONGO_DB_URL
    else
      console.log "environment #{env} not found"

