mongoose = require "mongoose"
Schema = mongoose.Schema

module.exports = (settings) ->
  tgetPretty = (path) ->
    path

  tvalidateUser = (req, instance, method, next) ->
    next(true)

  if(settings.userAssociated)
    uA = settings.userAssociated
    delete settings.userAssociated
  else
    uA = false
    
  if settings.alterPathValue
    tgetalter = setting.alterPathValue
    delete setting.alterPathValue
  else
    tgetalter = (instance, pathname, pathvalue) ->
      pathvalue
  if settings.pathDescriptions
    tgetdes = setting.pathDescriptions
    delete setting.pathDescriptions
  else
    tgetdes = (pathname) ->
      []
  if settings.getPrettyKey
    tgetPretty = settings.getPrettyKey
    delete settings.getPrettyKey
  if settings.instanceToDocSlug
    i2docslug = settings.instanceToDocSlug
    delete settings.instanceToDocSlug
  else
    i2docslug = (doc)->
      return
      
  if settings.docSlug
    tdocSlug = settings.docSlug
    delete settings.docSlug
  else if(settings.hasOwnProperty("name"))
    tdocSlug = "name"
  else
    throw new Error("need a docSlug Property")
  if settings.validateRequest
    tvalidateUser = settings.validateRequest
    delete settings.validateRequest
  ret = new Schema(settings)
  ret.static "_getDocSlug", ->
    tdocSlug

  ret.static("_alterPathValue", tgetalter)
  ret.static("_pathDescriptions", tgetdes)
  ret.static("_alterPathValue", tgetalter)
  ret.static("_getPrettyKey", tgetPretty)
  ret.static("_validateRequest", tvalidateUser)
  ret.method "_getModel", ()->
    this.model(this.constructor.modelName)
  ret.static "_userAssociated", ()->
    return uA
  ret.static "autocomplete", (path,value,next)->
    search = {}
    ret_err = []
    search[path] = new RegExp("^"+value, "i")
    this.find(search).select(path)\
    .sort(path).limit(20)\
    .exec (err,docs)->
      if(err)
        ret_err.push err
        next ret_err, "", "JSON"
        return
      ret_err = (undefined)
      next ret_err, docs, "JSON"
  ret