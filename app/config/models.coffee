mongoose = require "mongoose"
require "express-mongoose"

#Exports
module.exports = ->
  mongoose.model "user", require "../models/user/user"
