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
formidable = require "formidable"
fs = require "fs"
logger = require "../../utils/logger"
urlparse = require "url"
csv = require "fast-csv"
plugins = require "../../config/plugins.coffee"

plugins.initiateFilter("preRender")
boo = (true)
if(boo)
  console.log("here")
  checker = (path)->
    fs.readdirSync(path).forEach (file) ->
      console.log("ok")
      stats = fs.statSync(path+"/"+file)
      if(stats.isDirectory())
        checker(path+"/"+file)
      else
        require path+"/"+file
  checker(process.cwd()+"/app/models")
  boo = (false)
models = {}
models_array = []
modelNames = mongoose.modelNames()
console.log(modelNames)
for modelname in modelNames
  models[modelname] = mongoose.model(modelname)
  models_array.push models[modelname]
###
    mongoose.connection.db.collectionNames(function (err, names) {
        console.log(names); // [{ name: 'dbname.myCollection' }]
        module.exports.Collection = names;
    });
###
utils = require "./utils.coffee"

for key, value of utils
  console.log(key)

user_validation = (model, req, next)->
  model._validateRequest req, next


CRUD = require "./crud.coffee"

CRUD.method = (req,res,doc, method,query, next)->
  argsnames = utils.getArgs(doc[method])
  argvalues = []
  ret_err = []
  for name in argsnames
    if(query[name])
      argvalues.push query[name]
    else if(name.match(/req|request|res|response|next|cb|callback/))
      continue
    else
      ret_err.push { message:"need all arguments for the method: "+method}
      next ret_err, argvalues
      return
  if(argsnames[1].match(/res|response/))
    argvalues.unshift res
  if(argsnames[0].match(/req|request/))
    argvalues.unshift req
  if(argsnames[argsnames.length-1].match(/next|cb|callback/))
    argvalues.push (errors, data, render)->
      if(errors)
        if(Object.prototype.toString.call( errors ) == '[object Array]')
          ret_err.concat errors
        else 
          ret_err.push errors
        next ret_err, argvalues, render
        return
      next(null,data, render)
  doc[method].apply(doc, argvalues)

handleInstance = (path, req, res, callback)->
  if(path == "models/instance")
    res.locals.model.instance._getAssociated req, (instance)->
      res.locals.model.instance = instance
      callback path, req, res
  else
    callback path, req, res

handleUser = (path, req, res, callback)->
  if(req.user)
    req.user.__getAssociated req,(user)->
      req.user = user
      res.locals.user = user
      callback path, req, res, callback
  else
    callback path, req, res, callback

Render = (path, req, res)->
  handleInstance path, req, res, (path, req, res)->
    handleUser path, req, res, (path, req, res)->
      plugins.emit "preRender", req, res, (err_arr,req, res)->
        for errored in err_arr
          req.flash 'info'
          , req.i18n.t('ns.msg:flash.dberr') + errored.message
        res.render(path)


# User model's CRUD controller.
Route =
  # Lists all users
  index: (req, res) ->
    res.locals.model = {}
    res.locals.model.utils = utils
    res.locals.model.models_ref = models
    names = mongoose.modelNames()
    to_export = []
    to_count = []
    db_funk = ()->
      if names.length > 0
        name = names.pop()
        model = mongoose.model(name)
        if(model._associatedTo != "")
          db_funk()
          return
        console.log(name)
        mi = model
        model._validateRequest req, null, null, (valboo)->
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
        Render "models/index", req,res
        return
    db_funk()

  all:  (req, res) ->
    res.locals.model = {}
    res.locals.model.models = models
    res.locals.model.utils = utils
    patharray = urlparse.parse(req.originalUrl).pathname.split "/"
    patharray.splice 0,1
    names = mongoose.modelNames()
    if(names.indexOf(patharray[1]) == -1)
      req.flash 'info'
      , "Non Exsistant Model: "+patharray[1]
      res.statusCode = 404
      res.redirect("/model")
      return
    model = mongoose.model(patharray[1])
    res.locals.model.model = model
    model._validateRequest req, null, null, (validboo)->
      if(!validboo)
        req.flash 'info'
        , "You don't have access"
        res.statusCode = 403
        res.redirect("/model")
        return
      params
      if(req.method.toUpperCase() == "GET")
        params = req.query
        console.log(params)
      else if(req.method.toUpperCase() == "POST")
        params = req.body
      if(patharray.length < 3 || patharray[2] == "")
        CRUD.search model, params, null, (err, ret)->
          if(err)
            for errored in err
              req.flash 'info'
              , req.i18n.t('ns.msg:flash.dberr') + errored.message
            console.log "ERRORS: "+err
            console.log err
            console.log JSON.stringify(err)
            res.locals.model.request = ret
            res.locals.model.instances = []
            Render("models/model", req,res)
            return
          res.locals.model.request = params
          res.locals.model.instances = ret.docs
          console.log("DOCS"+ret.docs.length)
          console.log(ret.docs)
          Render("models/model",req,res)
      else if(patharray.length < 4)
        if(patharray[2].indexOf("search") == 0)
          another = patharray[2].split "-"
          if(another.length > 1)
            another = another[1]
          else
            another = (null)
          CRUD.search model, params, another, (err, ret)->
            if(err)
              for key, value of err
                req.flash 'info'
                , req.i18n.t('ns.msg:flash.dberr') + err.message
              res.locals.model.request = ret
              res.locals.model.instances = []
              Render("models/model",req,res)
              return
            res.locals.model.request = ret.params
            res.locals.model.instances = ret.docs
            Render("models/model",req,res)
        else if(patharray[2] == "create")
          CRUD.create req,res, model, params, (err, ret)->
            if(err)
              for key, value of err
                req.flash 'info'
                , JSON.stringify(err)
              res.redirect(utils.object2URL(model))
              return
            res.statusCode = 200
            res.redirect(utils.object2URL(instance))
        else
          schema = model.schema
          if(patharray[2].match("^_"))
            req.flash 'info'
            , "Non Exsistant Method in Model "+model.modelName
            res.statusCode = 404
            res.locals.model.params = params
            res.redirect(utils.object2URL(model))
          for key, value of schema.statics
            if(key.match("^_"))
              continue
            if(patharray[2] == key)
              CRUD.method req,res,model,key,params, (err, data,renderType)->
                console.log(err)
                console.log(data)
                console.log(renderType)
                if(!renderType)
                  if(err)
                    for key, value of err
                      req.flash 'info'
                      , req.i18n.t('ns.msg:flash.dberr') + value
                  res.locals.model[key] = data
                  Render("models/model",req,res)
                  return
                else if(renderType.toUpperCase() == "JSON")
                  if(err)
                    res.json(500,err)
                  else
                    res.json(200,data)
                  return
                else if(renderType.toUpperCase() == "PATH")
                    for key, value of err
                      req.flash 'info'
                      , req.i18n.t('ns.msg:flash.dberr') + err
                  res.locals.model[key] = data
                  Render(data.path,req,res)
              return
          req.flash 'info'
          , "Non Exsistant Method in Model "+model.modelName
          res.statusCode = 404
          res.locals.model.params = params
          res.redirect(utils.object2URL(model))
      else
        find = {}
        find[model._getDocSlug()] = decodeURIComponent(patharray[2])
        model.findOne find, (err,doc)->
          if(err)
            req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
            res.model = model
            res.redirect(utils.object2URL(model))
          if(!doc)
            req.flash 'info'
            , req.i18n.t('ns.msg:flash.dberr')\
            + "this "+model.modelName+" does not exist"
            res.statusCode = 404
            res.redirect(utils.object2URL(model))
          res.locals.model.instance = doc
          if(!patharray[3] || patharray[3] = "")
            Render("models/instance",req,res)
          else if(patharray[3] == "update")
          else if(patharray[3] == "delete")
          else
            schema = model.schema
            for key, value of schema.methods
              if(patharray[3] == key)
                CRUD.method req,res,doc,key,params, (err, data)->
                  if(err)
                    for key, value of err
                      req.flash 'info'
                      , req.i18n.t('ns.msg:flash.dberr') + err
                    res.locals.model.forms[key].args = ret
                    Render("models/instance",req,res)
                    return
                  if(!renderType)
                    res.locals.model[key] = data
                    Render("models/instance",req,res)
                  if(renderType.toUpperCase() == "JSON")
                      res.json(data)
                  if(renderType.toUpperCase() == "PATH")
                    res.locals.model[key] = data
                    Render(data.path,req,res)
                return
            req.flash 'info'
            , req.i18n.t('ns.msg:flash.dberr')\
            + "This method does not exist"
            res.statusCode = 404
            Render("models/instance",req,res)
Route.model = Route.index
module.exports = Route
