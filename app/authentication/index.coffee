fs = require("fs")
passport = require "passport"
User = require("../models/user/user")
utils = require "../controllers/model/utils.coffee"
mongoose = require "mongoose"

providers = {}
possprov = fs.readdirSync process.cwd()+"/app/authentication"
for name in possprov
  ref = name.split(".")[0]
  if(ref == "index")
    continue
  try
    providers[ref] = require "../authentication/"+name
    if(typeof providers[ref].strategy == "undefined")
      throw new Error("this provider doesn't have the appropiate methods")
  catch e
    delete providers[ref]
    console.log(e)


module.exports = 
  middleware: (req,res,next)->
    res.locals.model = {utils:utils}
    if(req.user)
      req.user.__getAssociated req,(user)->
        if(user.tandc)
          res.locals.tandc = {path:user.tandc}
        next()
    else
      next()

  passport: ()->
    config = require "../config/config"
    config.setEnvironment process.env.NODE_ENV
    if !process.env.HOSTNAME
      switch (process.env.NODE_ENV)
        when "development"
          url = "http://" + config.APP.hostname + ":" + config.PORT
        when "production"
          url = "http://" + config.APP.hostname
        when "test"
          url = "http://" + config.APP.hostname + ":" + config.PORT
    else
      url = process.env.HOSTNAME

    passport.serializeUser (user, done) ->
      console.log "serialize user"
      if user._id
        done null, user._id
      else
        done "no user"
        console.log "serialize user not found"

    passport.deserializeUser (id, done) ->
      console.log "deserialize"
      User.findOne _id: id, (err, user) ->
        unless err
          if user
            console.log "success"
            done null, user
          else
            console.log "user not found"
            done null, (false)
        else
          console.log "error: ", err
          done err, (false)

    for key, value of providers
      passport.use(value.strategy(url))
      
  routes: (app)->
    app.all "/authenticate/tandc", (req,res,next)->
      if(!req.user)
        res.statusCode = 404
        res.redirect "/"
        return
      else
        req.user.__getAssociated req,(user)->
          if(user.tandc)
            res.statusCode = 201
            res.locals.user = user
            res.locals.tandc.model = user.tandc_model
            res.locals.tandc.path = user.tandc
            res.locals.csrf = req.csrfToken()
            res.locals.model= {utils:utils}
            res.render "models/terms_and_conditions.blade"
            return
          req.flash('info', "You have Accepted all Terms and Conditions")
          res.redirect "/"
    app.post "/authenticate/tandc/:model", (req,res,next)->
      if(!req.user)
        res.statusCode = 404
        res.redirect "/"
        return
      model = mongoose.model(req.params.model)
      if(!model)
        res.statusCode = 404
        res.redirect "/"
        return
      if(!req.body || !req.body.accept)
        req.flash('info', "To get Further Functionality with "+\
        model._getPrettyKey(model.modelName)+" you must accept "+\
        "the Terms and Conditions for it")
        res.redirect "/authenticate/tandc"
      else
        instance = new model({user:req.user._id})
        instance.save (err, instance)->
          if(err)
            console.log("db error"+JSON.stringify(err))
            req.flash('info', JSON.stringify(err))
            res.redirect "/authenticate/tandc"
            return
          req.user.__getAssociated req,(user)->
            if(user.tandc)
              res.statusCode = 201
              res.redirect "authentication/tandc"
              return
            req.flash('info', "You have Accepted all Terms and Conditions")
            res.redirect "/"
    app.all "/authenticate/:method", (req, res, next)->
      if(req.isAuthenticated())
        req.flash('info', req.i18n.t('ns.msg:flash.alreadyauthorized'))
        res.redirect "/"
        return
      if(!providers.hasOwnProperty(req.params.method))
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.redirect "/"
        return
      if(!providers[req.params.method].hasOwnProperty("loginCallback"))
        passport.authenticate(req.params.method, { failureRedirect: "/" }) req,res,next
      else
        passport.authenticate( req.params.method, (err, user, info)->
          if(err)
            console.log(3)
            req.flash('info', JSON.stringify(err))
            res.redirect "/"
            return
          providers[req.params.method].loginCallback(req,res, user, info)
        ) req, res, next
    app.all "/authenticate/:method/setup", (req, res, next)->
      if(typeof providers[req.params.method] == "undefined")
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.statuscode = 404
        res.redirect "/"
        return
      if(typeof providers[req.params.method].setup == "undefined")
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.statuscode = 404
        res.redirect "/"
        return
      providers[req.params.method].setup req, res, next
    app.all "/authenticate/:method/callback", (req,res,next)->
      if(req.isAuthenticated())
        req.flash('info', req.i18n.t('ns.msg:flash.alreadyauthorized'))
        res.redirect "/"
        return
      if(typeof providers[req.params.method] == "undefined")
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.redirect "/"
        return
      if(typeof providers[req.params.method].authCallback == "undefined" || \
      !providers[req.params.method].authCallback)
        res.redirect "404"
        return
      passport.authenticate( req.params.method, (err, user, info)->
        console.log("should see this once")
        console.log err if err
        if user?
          req.logIn user, (err) ->
            unless err
              req.flash("info", req.i18n.t("ns.msg:flash." + info.message) + info.data + "
                " + req.i18n.t("ns.msg:flash." + info.message2))
              user.__getAssociated req,(user)->
                if(user.tandc)
                  res.statusCode = 201
                  res.redirect "authenticate/tandc"
                  return
                res.statusCode = 201
                res.redirect "/"
            else
              console.log("user login error: ", err)
              req.flash("info", req.i18n.t("ns.msg:flash.authorizationfailed"))
              res.statusCode = 403
              res.redirect "/"
      ) req, res, next
    app.all "/authenticate/:method/:tokenstring", (req,res,next)->
      if(req.isAuthenticated())
        req.flash('info', req.i18n.t('ns.msg:flash.alreadyauthorized'))
        res.redirect "/"
        return
      if(typeof providers[req.params.method] == "undefined")
        res.redirect "404"
        return
      if(typeof providers[req.params.method].tokenCallback == "undefined")
        res.redirect "404"
        return
      providers[req.params.method].tokenCallback(req,res,next)
      
