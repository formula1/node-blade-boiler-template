mongoose = require "mongoose"
utils = require "./utils.coffee"
CRUD = require "./crud.coffee"
fs = require "fs"

#res.locals.model.models = models

plugins = require "../../config/plugins.coffee"

plugins.initiateFilter("preRender")
plugins.initiateFilter("preRedirect")
plugins.initiateFilter("preData")
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

routeInit = (req,res,next)->
  names = mongoose.modelNames()
  if(names.indexOf(req.params.model) == -1)
    return next("nonexistant")
  model = mongoose.model(req.params.model)
  if(!model._RMV)
    return next("not ours")
  if(req.params.method)
    if(req.params.method.match("^_"))
      console.log("_ is hidden")
      return next("is hidden")
  next()


  
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
  res.locals.model.utils = utils
  if(!err)
    err_arr = []
  else if(Object.prototype.toString.call( err ) != '[object Array]' )
    err_arr = [err]
  else
    err_arr = err
  handleInstance path, req, res, (path, req, res)->
    handleUser path, req, res, (path, req, res)->
      plugins.emit "preRender", req, res, (err, req, res)->
        err_arr.concat err
        for errored in err_arr
          req.flash 'info', errored
        if(res.plugin.hasOwnProperty("redirect"))
          return res.redirect(res.plugin.redirect)
        if(res.plugin.hasOwnProperty("render"))
          return res.render res.plugin.render, {user: req.user, csrf:req.csrfToken()}
        res.render path, {user: req.user, csrf:req.csrfToken()}

Redirect = (path,req,res,err)->
  err_arr = []
  plugins.emit "preRedirect", req, res, (err, req, res)->
    err_arr.concat err
    for errored in err_arr
      req.flash 'info', errored
    if(res.plugin.hasOwnProperty("redirect"))
      return res.redirect(res.plugin.redirect)
    res.redirect path
        
module.exports =
  "/:model/:instance/": (req, res, next)->
    routeInit req, res, (err)->
      if(err)
        console.log(err)
        return next()
      plugins.emit "preData", req, res, (err_arr,req,res)->
        console.log(JSON.stringify(err_arr))
        model = mongoose.model(req.params.model)
        query = handleQuery(req)
        find = {}
        find[model._getDocSlug()] = decodeURIComponent(req.params.instance)
        model.findOne find, (err,doc)->
          if(err)
            req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
            res.model = model
            Redirect(utils.object2URL(model), req, res)
            return
          if(!doc)
            console.log("doc does not exist")
            return next()
          res.locals.model.instance = doc
          model._validateRequest req, doc, null, (validboo, path)->
            if(!validboo)
              req.flash 'info'
              , "You don't have access"
              res.statusCode = 403
              if(!path)
                path = "/"
              Redirect(path, req, res)
              return
            return Render("models/instance",req,res)
  "/:model/:instance/:method": (req, res, next)->
    routeInit req, res, (err)->
      if(err)
        console.log(err)
        return next()
      plugins.emit "preData", req, res, (err_arr,req,res)->
        model = mongoose.model(req.params.model)
        method = req.params.method
        query = handleQuery(req)
        find = {}
        find[model._getDocSlug()] = decodeURIComponent(req.params.instance)
        model.findOne find, (err,doc)->
          if(err)
            req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
            res.model = model
            Redirect(utils.object2URL(model), req, res)
            return
          if(!doc)
            console.log("doc does not exist")
            return next()
          res.locals.model.instance = doc
          model._validateRequest req, doc, method, (validboo, path)->
            if(!validboo)
              req.flash 'info'
              , "You don't have access"
              res.statusCode = 403
              if(!path)
                path = "/"
              Redirect(path, req, res)
              return
            if(method == "update")
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
            if(method == "delete")
              return next()
            schema = model.schema
            if(schema.methods.hasOwnProperty(method))
              CRUD.method req,res,doc,method,query, (err, data, renderType)->
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
    routeInit req, res, (err)->
      if(err)
        console.log(err)
        return next()
      plugins.emit "preData", req, res, (err_arr,req,res)->
        model = mongoose.model(req.params.model)
        model._validateRequest req, null, null, (validboo,path)->
          if(!validboo)
            req.flash 'info'
            , "You don't have access"
            res.statusCode = 403
            if(!path)
              path = "/"
            Redirect(path, req, res)
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
    routeInit req, res, (err)->
      if(err)
        console.log(err)
        return next()
      plugins.emit "preData", req, res, (err_arr,req,res)->
        model = mongoose.model(req.params.model)
        method = req.params.method
        query = handleQuery(req)
        model._validateRequest req, null, method, (validboo,path)->
          if(!validboo)
            req.flash 'info'
            , "You don't have access"
            res.statusCode = 403
            if(!path)
              path = "/"
            Redirect(path, req, res)
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
            return
          if(method == "create")
            CRUD.create req,res, model, query, (err, ret)->
              if(err)
                for key, value of err
                  req.flash 'info'
                  , JSON.stringify(err)
                Redirect(utils.object2URL(model), req, res)
                return
              res.statusCode = 200
              Redirect(utils.object2URL(ret), req, res)
              return
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
            return
          console.log("doesn't have property")
          next()