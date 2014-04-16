mongoose = require "mongoose"

module.exports = 
  object2URL: (object)->
    if(object instanceof mongoose.Document)
      model = mongoose.model(object.constructor.modelName)
      return "/model/"+model.modelName+"/"+object[model._getDocSlug()]+"/"
    else if(object.modelName)
      return "/model/"+object.modelName
  getArgs: (func)->
    fnStr = func.toString()
    fnStr = fnStr.replace(/\/\*.+?\*\/|\/\/.*(?=[\n\r])/g, '');
    result = fnStr.slice(fnStr.indexOf('(')+1, fnStr.indexOf(')'))\
    .match(/([^\s,]+)/g)
    if(result == null)
      result = []
    return result
  string2Model: (name)->
    mongoose.model(name)
  parse_params: ( model, params, next)->
    #I should also make it validate path types
    #or not at all, we will see...
    required = model.schema.requiredPaths()
    topass = {}
    for key, value of params
      if model.pathType(key) == "virtual"
        continue
      else if model.pathType(key) == "adhocOrUndefined"
        continue
      else if model.pathType(key) == "nested"
        console.log "we're not ready for this yet"
        continue
      else if model.pathType(key) == "real"
        if(required.indexOf(key) == -1)
          topass[key] = value
        else if(value != "")
          required.splice(required.indexOf(key), 1)
    if(required.length > 0)
      if(!err)
        err = []
      for key, value of required
        err.push {name:value, message:"Missing a required value:"+value}
    process.nextTick ()->
      next(err, topass)
  req_parse_params: (model, params, next)->
    #I should also make it validate path types
    #or not at all, we will see...
    indexes = model.schema.indexes()
    paths = model.schema.paths
    si = []
    toRegex = []
    toLoose = []
    err = []
    to_return = {}
    #Check for Regex Properties
    if(params["regex"])
      try
        toRegex = JSON.parse value
      catch
        err.push
          name:"Regex"
          message: "The Regex Parameter is not Properly Formatted"
    #Check for loose
    if params["loose"]
      try
        toLoose = JSON.parse value
      catch error
        err.push
          name:"Loose"
          message: "The Loose Parameter is not properly formatted"
    if(params.hasOwnProperty("sort"))
      if(paths.hasOwnProperty(params["sort"]))
        to_return._sort = params["sort"];
      else
        err.push
          name:"Sort"
          message: "Can't sort by a nonexistant property"
        to_return._sort = model._getDocSlug()
    else
      to_return._sort = model._getDocSlug()
    if(params.hasOwnProperty("page"))
      if(params["page"].match(/[0-9]/))
        to_return._page = params["page"]
      else
        err.push
          name:"Page"
          message: "the page must be a number"
        to_return._page = "0"
    else 
      to_return._page = "0"
    console.log(params);
    if(params["ipp"])
      if(params["ipp"].match(/[0-9]/))
        to_return._ipp = params["ipp"]
      else
        err.push
          name:"Ipp"
          message: "Items Per Page must be a number"
        to_return._ipp = "10"
    else
      to_return._ipp = "10"
    for key, value of paths
      if(params.hasOwnProperty(key))
        to_return[key] = decodeURIComponent(params[key])
    for key in toRegex
      try
        to_return[key] = new RegExp(decodeURIComponent(params[key]))
        temp = si.indexOf(key)
        if(temp != -1)
          si.splice(temp,1)
      catch error
        err.push
          name:"Regex"
          message: "Improperly formatted Regex"
    for key in toLoose
      try
        to_return[key] = new RegExp("*"+decodeURIComponent(params[key])+"*")
        temp = si.indexOf(key)
        if(temp != -1)
          si.splice(temp,1)
      catch error
        err.push
          name:"Regex"
          message: "Improperly formatted Regex"
  #  if(si.length == 0)
  #    err.push {name:value, message:"You should search by an index:"+value}
    console.log to_return
    if err.length == 0
      err = (undefined)
    process.nextTick ()->
      next(err, to_return)
    #Class
    #-Create Instance
    #-Search and Request|Update|Delete
    #-(Static Methods)
