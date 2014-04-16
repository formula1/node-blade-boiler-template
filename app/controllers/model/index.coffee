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
      if(file == "user")
        return
      else if(stats.isDirectory())
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


CRUD = {}
CRUD.create=(model, params, next)->
  utils.parse_params model, params, (err, topass)->
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
        ret_err = (undefined)
        next ret_err, instance
    instance.save(save_cb)
    return
  return
CRUD.search=(model, params, another, next)->
  if(another == null)
    # additionally need sort parameter
    # Also need pagination
    ret_err = []
    utils.req_parse_params model, params, (err, topass)->
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
      #pagination
      console.log(topass)
      sort = topass._sort
      delete topass._sort
      page = topass._page
      delete topass._page
      console.log "IPP: "+topass.ipp
      ipp = topass._ipp
      delete topass._ipp
      model.find(topass)\
      .sort(sort).skip(page*ipp).limit(ipp)\
      .populate(to_pop).exec (err, instances)->
        if(err)
          ret_err.push err
          next ret_err, topass
          return
        ret_err = (undefined)
        next ret_err, {params:topass, docs:instances}
  else if(another.toUpperCase() == "delete")
    # need to consider if they are just IDS
    #I'm not going to pass a regex to search for IDs, thats rediculous
    utils.req_parse_params model, params, (err, topass)->
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
    utils.req_parse_params model, params, (err, topass)->
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
  
Render = (path, req, res)->
  for key, value of res.locals.model.models
    console.log(key)

  modelcounter = 0;
  assoc_model = ()->
    if(modelcounter == models_array.length)
      plugins.emit "preRender", req, res, (err_arr,req, res)->
        for errored in err_arr
          req.flash 'info'
          , req.i18n.t('ns.msg:flash.dberr') + errored.message
        res.locals.user = req.user
        res.render(path)
    else if(models_array[modelcounter]._userAssociated && models_array[modelcounter]._userAssociated())
      models_array[modelcounter].findOne({user:req.user._id})\
      .populate("*").exec (err,doc)->
        if(err)
          console.log(err)
        if(doc)
          req.user[models_array[modelcounter].modelName] = doc
        modelcounter++
        assoc_model()
    else
      modelcounter++
      assoc_model()
  assoc_model()
  

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
        if(name.toLowerCase() == "user")
          db_funk()
          return
        model = mongoose.model(name)
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
    if(patharray[1].match("User"))
      req.flash 'info'
      , "Non Exsistant Model"
      res.statusCode = 404
      res.redirect("/model")
      return
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
          CRUD.create model, params, (err, ret)->
            if(err)
              for key, value of err
                req.flash 'info'
                , req.i18n.t('ns.msg:flash.dberr') + err.message
              res.locals.model.form.tocreate = ret
              Render("models/model",req,res)
              return
            res.locals.model.instance = ret
            res.locals.model.schema = model.schema
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
        model.find find, (err,docs)->
          if(err)
            req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
            res.model = model
            res.redirect(utils.object2URL(model))
          if(docs.length == 0)
            req.flash 'info'
            , req.i18n.t('ns.msg:flash.dberr')\
            + "this "+model.modelName+" does not exist"
            res.statusCode = 404
            res.redirect(utils.object2URL(model))
          doc = docs[0]
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
