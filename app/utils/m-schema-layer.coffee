mongoose = require "mongoose"
Schema = mongoose.Schema

module.exports = (settings) ->
  tgetPretty = (path) ->
    path

  tdocSlug = "_id"
  tvalidateUser = (req, instance, method, next) ->
    next(true)

  if settings.getPretty
    tgetPretty = settings.getPretty
    delete settings.getPretty
  if settings.docSlug
    tdocSlug = settings.docSlug
    delete settings.docSlug
  if settings.validateUser
    tvalidateUser = settings.validateUser
    delete settings.validateUser
  ret = new Schema(settings)
  ret.static "getDocSlug", ->
    tdocSlug

  ret.static("getPretty", tgetPretty)
  ret.static("validateUser", tvalidateUser)
  ret