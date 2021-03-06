#Load external dependencies
express = require "express"
stylus = require "stylus"
mongoose = require "mongoose"
i18next = require "i18next"
#Load local dependencies
config = require "./config/config"
models = require "./config/models"
apps = require "./config/apps"
routes = require "./config/routes"
#engine = require "./config/engine"
fs = require "fs"

#Load and intitialize logger
logger = require "./utils/logger"
logCategory = "APP config"
# TODO store log messages in the db
logger.configure()

# Create server and set environment
app = express()
app.settings.env = process.env.NODE_ENV if process.env.NODE_ENV
app.configure "production", "development", "test", ->
  config.setEnvironment app.settings.env

logger.info "--- App server created and local env set to: " \
  + app.settings.env, logCategory

#Define Port
app.port = config.PORT
logger.info "--- Server running on port: " + app.port, logCategory

#Connect to database
dbconnection = require "./utils/dbconnect"

dbconnection.init (err, result) ->
  if result
    logger.info "Database initialized: " + result, logCategory
#Exports
module.exports = ->
  #  Load Mongoose Models
  models app
  # Load Expressjs config
  apps app
  # Init engine.io
  # engine.use app
  # Load routes config
  routes app
  #
  app
logger.info "--- Modules loaded into namespace ---", logCategory
