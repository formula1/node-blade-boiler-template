### Models
# Used to simplify CRUD interactions with mongoose
#
# static names to avoid
# -validateUser
# -getDocSlug
# -getPretty
    -model title
    -a path
    -a function name
    -etc
# -alter and hiddens attributes
#   -When you would rather show value b than value a
      (good for showing titles rather than slugs)
#   -something I'm not going to worry about right now...
    -this would hook into pre save,
      if one of the parameters (namely the hidden/alter)
      doesn't exsist, we make it
#
# Utils
# -get url from object
# -get function args
###

mongoose = require "mongoose"



User = require "../models/user/user"
formidable = require "formidable"
fs = require "fs"
logger = require "../utils/logger"
csv = require "fast-csv"
###
    mongoose.connection.db.collectionNames(function (err, names) {
        console.log(names); // [{ name: 'dbname.myCollection' }]
        module.exports.Collection = names;
    });
###
utils =
  object2URL: (object)->
    if(object instanceof mongoose.Document)
      model = mongoose.model(object.constructor.modelName)
      return "/model/"+model.modelName+"/"+object[model.getDocSlug()]+"/"
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


user_validation = (model, req, next)->
  model.validateUser req, next


parse_params = ( model, params, next)->
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

req_parse_params = (model, params, next)->
  #I should also make it validate path types
  #or not at all, we will see...
  indexes = model.schema.indexes()
  si = []
  topass = {}
  toRegex = []
  toLoose = []
  err = []
  for key, value of params
    if model.pathType(key) == "virtual"
      continue
    else if model.pathType(key) == "adhocOrUndefined"
      if key == "regex"
        try
          toRegex = JSON.parse value
        catch
          err.push
            name:"Regex"
            message: "The Regex Parameter is not Properly Formatted"
      if key == "loose"
        try
          toLoose = JSON.parse value
        catch
          err.push
            name:"Loose"
            message: "The Loose Parameter is not properly formatted"
      continue
    else if model.pathType(key) == "nested"
      console.log "we're not ready for this yet"
      continue
    else if model.pathType(key) == "real"
      if((temp = required.indexOf(key)) == -1)
        topass[key] = value
      else if(value != "")
        si.push key
        indexes.splice(temp, 1)
  for key of toRegex
    topass[key] = new RegEx(topass[key])
    temp = si.indexOf(key)
    if(temp != -1)
      si.splice(temp,1)
  for key of toLoose
    topass[key] = new RegEx("*"+topass[key]+"*")
    temp = si.indexOf(key)
    if(temp != -1)
      si.splice(temp,1)
#  if(si.length == 0)
#    err.push {name:value, message:"You should search by an index:"+value}
    
  if err.length == 0
    err = (undefined)
  process.nextTick ()->
    next(err, topass)
  #Class
  #-Create Instance
  #-Search and Request|Update|Delete
  #-(Static Methods)

CRUD = {}
CRUD.create=(model, params, next)->
  parse_params model, params, (err, topass)->
    ret_err = []
    if(err)
      ret_err.push err
      next(ret_err, topass)
      return
    instance = new model(topass)
    save_cb = (err, instance)->
      if err
        ret_err.push err
        next ret_err, topass
        return
      else
        ret_err = undefined
        next ret_err, instance
    instance.save(save_cb)
    return
  return
CRUD.req=(model, params, another, next)->
  if(another == null)
    # additionally need sort parameter
    # Also need pagination
    ret_err = []
    req_parse_params model, params, (err, topass)->
      if(err)
        ret_err.push err
        next ret_err, topass
        return
      paths = model.schema.paths
      to_pop = ""
      for key, path of paths
        if(key != "_id")
          if(path.caster)
            if(path.caster.instance == "ObjectID")
              to_pop += path.path+" "
          else if(path.instance == "ObjectID")
            to_pop += path.path+" "
      if(to_pop != "")
        to_pop = to_pop.substring(0,to_pop.length-1)
      model.find(topass).populate(to_pop).exec (err, instances)->
        if(err)
          ret_err.push err
          next ret_err, topass
          return
        ret_err = (undefined)
        next ret_err, {params:topass, docs:instances}
  else if(another.toUpperCase() == "delete")
    # need to consider if they are just IDS
    #I'm not going to pass a regex to search for IDs, thats rediculous
    req_parse_params model, params, (err, topass)->
      if(err)
        ret_err.push err
        next ret_err, topass
        return
      model.find topass, (err, instances)->
        if(err)
          ret_err.push err
          next ret_err, topass
          return
        ret_err = (undefined)
        next ret_err, {params:topass, docs:instances}
  else if(another.toUpperCase() == "update")
    # need to consider if they are just IDS
    req_parse_params model, params, (err, topass)->
      if(err)
        ret_err.push err
        next ret_err, topass
        return
      model.find topass, (err, instances)->
        if(err)
          ret_err.push err
          next ret_err, topass
          return
        ret_err = (undefined)
        next ret_err, {params:topass, docs:instances}
CRUD.update = ()->
  return
CRUD.delete = ()->
  return

CRUD.method = (doc, method,query, next)->
  argsnames = getParamNames(doc[method])
  argvalues = []
  ret_err = []
  for name in argsnames
    if(value == query[name])
      argvalues.push value
    else if(name.match(/next|cb|callback/))
      continue
    else
      ret_err.push { message:"need all arguments for the method: "+method}
      next ret_err, argvalues
      return
  argvalues.push (err, data)->
    if(err)
      ret_err.push err
      next ret_err, argvalues
      return
    next(null,data)
  doc[method].apply(doc, argvalues)
  
getParamNames =(func)->
  fnStr = func.toString().replace(STRIP_COMMENTS, '')
  result = fnStr.slice(\
  fnStr.indexOf('(')+1
  , fnStr.indexOf(')')\
  ).match(/([^\s,]+)/g)
  if( result == null)
    result = []
  return result


renderClass = (model, code, path)->
  
  res.statusCode = code
  res.render(path)
  return

renderInstance = ()->
  return

# User model's CRUD controller.
Route =
  # Lists all users
  index: (req, res) ->
    res.locals.model = {}
    res.locals.model.utils = utils
    names = mongoose.modelNames()
    to_export = []
    to_count = []
    db_funk = ()->
      if names.length > 0
        name = names.pop()
        if(name.toLowerCase() == "user")
          db_funk()
          return
        model = mongoose.model(name)
        mi = model
        model.validateUser req, null, null, (valboo)->
          if valboo
            model.count (err, count)->
              if err
                req.flash 'info'
                , req.i18n.t('ns.msg:flash.dberr') + error.message
                db_funk()
                return
              to_count.push count
              to_export.push mi
              db_funk()
          else
            db_funk()
      else
        res.locals.model.models = to_export
        res.locals.model.count = to_count
        res.render "models/index"
        return
    db_funk()

  all:  (req, res) ->
    res.locals.model = {}
    res.locals.model.utils = utils
    patharray = req.originalUrl.split "/"
    patharray.splice 0,1
    if(patharray[1].match("User"))
      req.flash 'info'
      , "Non Exsistant Model"
      res.statusCode = 404
      res.redirect("/model")
      return
    names = mongoose.modelNames()
    if(names.indexOf(patharray[1]) == -1)
      req.flash 'info'
      , "Non Exsistant Model"
      res.statusCode = 404
      res.redirect("/model")
      return
    model = mongoose.model(patharray[1])
    res.locals.model.model = model
    model.validateUser req, null, null, (validboo)->
      if(!validboo)
        req.flash 'info'
        , "You don't have access"
        res.statusCode = 403
        res.redirect("/model")
        return
      params
      if(req.method.toUpperCase() == "GET")
        params = req.query
      else if(req.method.toUpperCase() == "POST")
        params = req.body
      if(patharray.length < 3 || patharray[2] == "")
        CRUD.req model, {}, null, (err, ret)->
          if(err)
            for errored in err
              req.flash 'info'
              , req.i18n.t('ns.msg:flash.dberr') + errored.message
            console.log "ERRORS: "+err
            console.log err
            console.log JSON.stringify(err)
            res.locals.model.request = ret
            res.locals.model.instances = []
            res.render("models/model")
            return
          res.locals.model.request = ret.params
          res.locals.model.instances = ret.docs
          console.log("DOCS"+ret.docs.length)
          res.render("models/model")
      else if(patharray.length < 4)
        if(patharray[2].indexOf("search") == 0)
          another = patharray[2].split "-"
          if(another.length > 1)
            another = another[1]
          else
            another = (null)
          CRUD.req model, params, another, (err, ret)->
            if(err)
              for key, value of err
                req.flash 'info'
                , req.i18n.t('ns.msg:flash.dberr') + err.message
              res.locals.model.request = ret
              res.locals.model.instances = []
              res.render("models/model")
              return
            res.locals.model.request = ret.params
            res.locals.model.instances = ret.docs
            res.render("models/model")
        else if(patharray[2] == "create")
          CRUD.create model, params, (err, ret)->
            if(err)
              for key, value of err
                req.flash 'info'
                , req.i18n.t('ns.msg:flash.dberr') + err.message
              res.locals.model.form.tocreate = ret
              res.render("models/model")
              return
            res.locals.model.instance = ret
            res.locals.model.schema = model.schema
            res.statusCode = 200
            res.redirect(utils.object2URL(instance))
        else
          schema = model.schema
          if(patharray[2].match("validateUser|getDocSlug|getPretty"))
            req.flash 'info'
            , "Non Exsistant Method in Model "+model.modelName
            res.statusCode = 404
            res.locals.model.params = params
            res.redirect(utils.object2URL(model))
          for key, value of schema.statics
            if(key.match("validateUser|getDocSlug|getPretty"))
              continue
            if(patharray[2] == key)
              CRUD.method model,key,req.query, (err, data)->
                if(err)
                  for key, value of err
                    req.flash 'info'
                    , req.i18n.t('ns.msg:flash.dberr') + err
                  res.locals.model.model[key] = ret
                  res.render("models/model")
                  return
                res.locals.model[key] = data
                res.render("models/model")
              return
          req.flash 'info'
          , "Non Exsistant Method in Model "+model.modelName
          res.statusCode = 404
          res.locals.model.params = params
          res.redirect(utils.object2URL(model))
      else
        find = {}
        find[model.getDocSlug()] = patharray[2]
        model.find find, (err,docs)->
          if(err)
            req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
            res.model = model
            res.render("models/model")
          if(docs.length == 0)
            req.flash 'info'
            , req.i18n.t('ns.msg:flash.dberr')\
            + "this "+model.modelName+" does not exist"
            res.statusCode = 404
            res.render("models/model")
          doc = docs[0]
          res.locals.model.instance = doc
          if(!patharray[3] || patharray[3] = "")
            res.render("models/instance")
          else if(patharray[3] == "update")
          else if(patharray[3] == "delete")
          else
            schema = model.schema
            for key, value of schema.methods
              if(patharray[3] == key)
                CRUD.method doc,key,req.query, (err, data)->
                  if(err)
                    for key, value of err
                      req.flash 'info'
                      , req.i18n.t('ns.msg:flash.dberr') + err
                    res.locals.model.forms[key].args = ret
                    res.render("models/instance")
                    return
                  res.locals.model.forms[key].data = data
                  res.render("models/instance")
                return
            req.flash 'info'
            , req.i18n.t('ns.msg:flash.dberr')\
            + "This method does not exist"
            res.statusCode = 404
            res.render("models/instance")
Route.model = Route.index
module.exports = Route
