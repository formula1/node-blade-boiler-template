mongoose = require "mongoose"
utils = require "./utils.coffee"
CRUD = require "./crud.coffee"
fs = require "fs"

#res.locals.model.models = models

plugins = require "../../config/plugins.coffee"

plugins.initiateFilter("preRender")
boo = (true)
if(boo)
  checker = (path)->
    fs.readdirSync(path).forEach (file) ->
      stats = fs.statSync(path+"/"+file)
      if(stats.isDirectory())
        checker(path+"/"+file)
      else
        require path+"/"+file
  checker(process.cwd()+"/app/models")
  boo = (false)

handleQuery = (req)->
  if(req.method.toUpperCase() == "GET")
    return req.query
  else if(req.method.toUpperCase() == "POST")
    return req.body
    
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
      callback path, req, res
  else
    callback path, req, res

Render = (path, req, res, err)->
  if(!err)
    err = []
  else if(Object.prototype.toString.call( err ) != '[object Array]' )
    err= [err]
  handleInstance path, req, res, (path, req, res)->
    handleUser path, req, res, (path, req, res)->
      plugins.emit "preRender", req, res, (err_arr,req, res)->
        err_arr.concat err
        for errored in err_arr
          req.flash 'info', errored
        res.render path, {user: req.user}

        
module.exports =
  "/:model/:instance/": (req, res, next)->
    query = handleQuery(req)
    names = mongoose.modelNames()
    if(names.indexOf(req.params.model) == -1)
      return next()
    model = mongoose.model(req.params.model)
    find = {}
    find[model._getDocSlug()] = decodeURIComponent(req.params.instance)
    model.findOne find, (err,doc)->
      if(err)
        req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
        res.model = model
        res.redirect(utils.object2URL(model))
        return
      if(!doc)
        console.log("doc does not exist")
        return next()
      res.locals.model.instance = doc
      model._validateRequest req, doc, null, (validboo)->
        if(!validboo)
          req.flash 'info'
          , "You don't have access"
          res.statusCode = 403
          res.redirect("/")
          return
        return Render("models/instance",req,res)
  "/:model/:instance/:method": (req, res, next)->
    query = handleQuery(req)
    names = mongoose.modelNames()
    if(names.indexOf(req.params.model) == -1)
      return next()
    if(req.params.method.match("^_"))
      console.log("_ is hidden")
      return next()
    model = mongoose.model(req.params.model)
    find = {}
    find[model._getDocSlug()] = decodeURIComponent(req.params.instance)
    model.findOne find, (err,doc)->
      if(err)
        req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
        res.model = model
        res.redirect(utils.object2URL(model))
        return
      if(!doc)
        console.log("doc does not exist")
        return next()
      res.locals.model.instance = doc
      model._validateRequest req, doc, req.params.method, (validboo)->
        if(!validboo)
          req.flash 'info'
          , "You don't have access"
          res.statusCode = 403
          res.redirect("/")
          return
        if(req.params.method == "update")
          console.log("updating")
          CRUD.update req,res,doc,query, (err, data)->
            if(err)
              for key, value of err
                req.flash 'info'
                , req.i18n.t('ns.msg:flash.dberr') + err
              #res.locals.model.forms[key].args = data
              return Render("models/instance",req,res,err)
            res.locals.model.instance = data
            return Render("models/instance",req,res)
          return
        if(req.params.method == "delete")
          return next()
        schema = model.schema
        if(schema.methods.hasOwnProperty(req.params.method))
          CRUD.method req,res,doc,req.params.method,query, (err, data, renderType)->
            if(err)
              #res.locals.model.forms[key].args = data
              return Render("models/instance",req,res, err)
            if(!renderType)
              res.locals.model[key] = data
              return Render("models/instance",req,res)
            if(renderType.toUpperCase() == "JSON")
                return res.json(data)
            if(renderType.toUpperCase() == "PATH")
              res.locals.model[key] = data
              return Render(data.path,req,res)
          return
        console.log("can't find it")
        next()
  "/:model/": (req, res, next)->
    names = mongoose.modelNames()
    method = req.params.method
    if(names.indexOf(req.params.model) == -1)
      console.log("non-existant model")
      return next()
    model = mongoose.model(req.params.model)
    model._validateRequest req, null, null, (validboo)->
      if(!validboo)
        req.flash 'info'
        , "You don't have access"
        res.statusCode = 403
        res.redirect("/")
        return
      res.locals.model.utils = utils
      res.locals.model.model = model
      query = handleQuery(req)
      CRUD.search model, query, null, (err, ret)->
        if(err)
          res.locals.model.request = ret
          res.locals.model.instances = []
          Render("models/model", req,res, err)
          return
        res.locals.model.request = query
        res.locals.model.instances = ret.docs
        return Render("models/model",req,res)
  "/:model/:method": (req, res, next)->
    names = mongoose.modelNames()
    method = req.params.method
    if(names.indexOf(req.params.model) == -1)
      console.log("non-existant model")
      return next()
    model = mongoose.model(req.params.model)
    if(method.match("^_"))
      console.log("_ is hidden")
      return next()
    model._validateRequest req, null, method, (validboo)->
      if(!validboo)
        req.flash 'info'
        , "You don't have access"
        res.statusCode = 403
        res.redirect("/")
        return
      if(method =="search")
        CRUD.search model, query, null, (err, ret)->
          if(err)
            res.locals.model.request = ret
            res.locals.model.instances = []
            Render("models/model",req,res,err)
            return
          res.locals.model.request = ret.params
          res.locals.model.instances = ret.docs
          return Render("models/model",req,res)
      if(method == "create")
        CRUD.create req,res, model, query, (err, ret)->
          if(err)
            for key, value of err
              req.flash 'info'
              , JSON.stringify(err)
            res.redirect(utils.object2URL(model))
            return
          res.statusCode = 200
          res.redirect(utils.object2URL(instance))
          return
      schema = model.schema
      if(schema.statics.hasOwnProperty(method))
        CRUD.method req,res,model,method,query, (err, data,renderType)->
          console.log(err)
          console.log(data)
          console.log(renderType)
          if(!renderType)
            res.locals.model[key] = data
            return Render("models/model",req,res, err)
          if(renderType.toUpperCase() == "JSON")
            if(err)
              return res.json(500,err)
            return res.json(200,data)
          if(renderType.toUpperCase() == "PATH")
            res.locals.model[key] = data
            return Render(data.path,req,res,err)
      console.log("doesn't have property")
      next()