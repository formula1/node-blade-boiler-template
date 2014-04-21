mongoose = require "mongoose"
fs = require "fs"
module.exports = 
  txt2HTML: (path)->
    text = fs.readFileSync(process.cwd()+"/views/"+path, {encoding:"utf-8"})
    text = text.replace(/\n|\r|\r\n/g, "<br/>")
    text = text.replace(/\t/g, '<span style="display:inline-block;width:12.5%"></span>')
    return text
  getAssociatedInstances: (req,instance, callback)->
    model_list = mongoose.modelNames()
    modelname = instance.constructor.modelName
    console.log("modelname: "+modelname)
    associated_instances = []
    unfound_models = []
    assoc_model = ()->
      if(model_list.length == 0)
        callback(associated_instances, unfound_models)
        return
      else 
        cur_model = mongoose.model(model_list.pop())
        if(cur_model._associatedTo() == modelname)
          tofind = {}
          tofind[modelname] = instance._id
          cur_model.findOne(tofind)\
          .populate("*").exec (err,doc)->
            if(err)
              console.log(err)
              assoc_model()
            if(doc)
              cur_model._validateRequest req, doc, undefined, (boo)->
                if(boo)
                  associated_instances.push doc
                assoc_model()
            else
              cur_model._validateRequest req, cur_model, undefined, (boo)->
                if(boo)
                  unfound_models.push cur_model
                assoc_model()
        else
          assoc_model()
    assoc_model()

  object2URL: (object)->
    if(object instanceof mongoose.Document)
      model = mongoose.model(object.constructor.modelName)
      return "/"+model.modelName+"/"+object[model._getDocSlug()]+"/"
    else if(object.modelName)
      return "/"+object.modelName+"/"
  getArgs: (func)->
    fnStr = func.toString()
    fnStr = fnStr.replace(/\/\*.+?\*\/|\/\/.*(?=[\n\r])/g, '');
    result = fnStr.slice(fnStr.indexOf('(')+1, fnStr.indexOf(')'))\
    .match(/([^\s,]+)/g)
    if(result == null)
      result = []
    return result
  instance2Model: (instance)->
    mongoose.model(instance.constructor.modelName)
  string2Model: (name)->
    mongoose.model(name)
  parse_params: ( model, params, next)->
    #I should also make it validate path types
    #or not at all, we will see...
    schema = model.schema
    required = schema.requiredPaths()
    topass = {}
    err = []
    for key, value of schema.paths
      if(key.match("^_"))
        continue
      if(typeof params[key] != undefined && params[key] != "" && params[key] != null)
        topass[key] = params[key]
      else if(schema.paths[key].isRequired)
        err.push {name:key, message:"Missing a required value:"+key}
    if(err.length == 0)
      err = undefined
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
    if err.length == 0
      err = (undefined)
    process.nextTick ()->
      next(err, to_return)
    #Class
    #-Create Instance
    #-Search and Request|Update|Delete
    #-(Static Methods)
