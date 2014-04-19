mongoose = require "mongoose"
Schema = mongoose.Schema
utils = require "../controllers/model/utils.coffee"

module.exports = (settings, overloads) ->
  tgetPretty = (path) ->
    path

  tvalidateUser = (req, model_or_instance, method, next) ->
    next(true)

  if(overloads)
    assocTo = ""
    if(overloads.associatedTo)
      if(typeof overloads.associatedTo == "string")
        assocTo = overloads.associatedTo
        if(assocTo == "user")
          if(overloads.terms_and_conditions)
            terms_and_conditions = overloads.terms_and_conditions
  
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
  if(terms_and_conditions)
    ret.static "TandC", ()->
      return terms_and_conditions

  ret.method "_createHook", (req,res,next)->
    next()
  ret.static("_alterPathValue", tgetalter)
  ret.static("_pathDescriptions", tgetdes)
  ret.static("_getPrettyKey", tgetPretty)
  ret.static("_validateRequest", tvalidateUser)
  ret.method "_getModel", ()->
    mongoose.model(this.constructor.modelName)
  ret.method "_getAssociated", (req, callback)->
    instance = this
    utils.getAssociatedInstances req, this, (found, unfound)->
      instance.associated = found
      callback(instance)

  ret.static "_associatedTo", ()->
    return assocTo
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