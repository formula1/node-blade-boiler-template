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
        tdocSlug = mongoose.model(overloads.associatedTo)._getDocSlug()
        console.log overloads
        if(assocTo == "user")
          console.log("assoc to user")
          console.log overloads
          if(overloads.tandc)
            terms_and_conditions = overloads.tandc
  
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
  else if(!tdocSlug)
    throw new Error("need a docSlug Property")
  if settings.validateRequest
    tvalidateUser = settings.validateRequest
    delete settings.validateRequest

  if(!settings[tdocSlug])
    settings[tdocSlug] = {type:String,unique:true}

  ret = new Schema(settings)
  ret.static "_getDocSlug", ->
    tdocSlug
  if(terms_and_conditions)
    console.log("terms")
    ret.static "_TandC", ()->
      return terms_and_conditions

  ret.static "_RMV", true

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
  if(assocTo != "" && typeof assocTo != "undefined")
    ret.pre "save", (next)->
      console.log("pre")
      instance = this
      imodel = this._getModel()
      model = mongoose.model(imodel._associatedTo())
      console.log("the model: "+this[model.modelName])
      model.findOne {_id:this[model.modelName]}, (err, doc)->
        if(err)
          return next(err)
        if(!doc)
          return next("this doc does not exist")
        console.log("my slug: "+imodel._getDocSlug())
        console.log("its slug: "+model._getDocSlug())
        instance[imodel._getDocSlug()] = doc[model._getDocSlug()]
        next()
       
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