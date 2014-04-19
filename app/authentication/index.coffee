fs = require("fs")
passport = require "passport"
User = require("../models/user/user")

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
    app.all "/authenticate/:method", (req, res, next)->
      if(req.isAuthenticated())
        req.flash('info', req.i18n.t('ns.msg:flash.alreadyauthorized'))
        res.redirect "index"
        return
      if(typeof providers[req.params.method] == "undefined")
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.redirect "index"
        return
      if(typeof providers[req.params.method].loginCallback == "undefined")
        passport.authenticate(req.params.method, { failureRedirect: "/" }) req,res,next
      else
        passport.authenticate req.params.method, (err, user, info)->
          if(err)
            console.log(3)
            next(err)
            return
          providers[req.params.method].loginCallback(req,res, user, info)
    app.all "/authenticate/:method/setup", (req, res, next)->
      if(typeof providers[req.params.method] == "undefined")
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.statuscode = 404
        res.redirect "index"
        return
      if(typeof providers[req.params.method].setup == "undefined")
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.statuscode = 404
        res.redirect "index"
        return
      providers[req.params.method].setup req, res, next
    app.all "/authenticate/:method/callback", (req,res,next)->
      if(req.isAuthenticated())
        req.flash('info', req.i18n.t('ns.msg:flash.alreadyauthorized'))
        res.redirect "index"
        return
      if(typeof providers[req.params.method] == "undefined")
        req.flash('info', req.i18n.t('this method of authorization isn\'t Accepted'))
        res.redirect "index"
        return
      if(typeof providers[req.params.method].authCallback == "undefined" || \
      !providers[req.params.method].authCallback)
        res.redirect "404"
        return
      passport.authenticate( req.params.method, (err, user, info)->
        console.log err if err
        if user?
          req.logIn user, (err) ->
            unless err
              req.flash("info", req.i18n.t("ns.msg:flash." + info.message) + info.data + "
                " + req.i18n.t("ns.msg:flash." + info.message2))
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
        res.redirect "index"
        return
      if(typeof providers[req.params.method] == "undefined")
        res.redirect "404"
        return
      if(typeof providers[req.params.method].tokenCallback == "undefined")
        res.redirect "404"
        return
      providers[req.params.method].tokenCallback(req,res,next)
      
