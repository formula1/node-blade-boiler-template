messages = require "../utils/messages"
Emailer = require "../utils/emailer"
LocalStrategy = require('passport-local').Strategy
Password = require('../models/user/password')
User = require("../models/user/user")
config = require "../config/config"
utils = require "../controllers/model/utils.coffee"

module.exports = 
  setup: (req, res, next)->
    mail_templates = 
      reset: (user)->
        return {
          template: "reset"
          subject: "reseting your password"
          to:
            name: user.name
            surname: user.surname
            email: user.email
        }

      activate: (user)->
        return {
          template: "activation"
          subject: "account activation"
          to:
            name: user.name
            surname: user.surname
            email: user.email
        }

      
                  
    SendMail = (req, res, template, user) ->
      options = mail_templates[template](user)
      if(template == "reset")
        action = "/authenticate/local/"
      else if(template == "activate")
        action = "/authenticate/local/"
      data = {}
      if config.APP.hostname is 'localhost'
        console.log("is localhost")
        data.link = "http://" + config.APP.hostname + ":" + config.PORT + action + user.tokenString
      else
        console.log("isnt localhost")
        data.link = config.APP.hostname + action + user.tokenString
      linkinfo = req.i18n.t('ns.msg:flash.activationlink') + "."
      options.from = {email:"samtobia@gmail.com"}


      console.log("sending message to: ", options.to.email)
      mailer = new Emailer(options, data)
      mailer.send (err,message)->
        unless err
          res.statusCode = 201
          req.flash('info', linkinfo)
          res.redirect "index"

        else
          console.log err
          res.statusCode = 400
          req.flash('info', req.i18n.t('ns.msg:flash.sendererror') + ".")
          res.redirect "index"

    handleError = (message, err)->
      console.log(message)
      req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err.message)
      res.statusCode = 500
      res.redirect("index")

    delete req.body.remember_me
    console.log("server csrf: " +  req.csrfToken())
    if req.body && req.body.email?
      req.body.email = req.body.email.toLowerCase()
      User.findOne { email:req.body.email }, (err,user) ->
        if err
          handleError("user find error", err)
        else
        action = null
        options = null
        if user
          password = Password.findOne {user:user._id}, (err,password)->
            if(err)
              handleError("password find error", err)
              return
            options
            if(password)
              if(password.active)
                SendMail(req, res, "reset", user)
                return
              else
                SendMail(req, res, "activate", user)
                return
            else
              password = new Password {user:user._id}
              password.save (err, password)->
                if(err)
                  handleError("password save error", err)
                  return
                  SendMail(req, res, "activate", user)
        else
          #need to create user and create Password
          user = new User({email:req.body.email})
          user.save (err, user)->
            if(err)
              handleError("user save error", err)
              return
            password = new Password {user:user._id}
            password.save (err, password)->
              if(err)
                handleError("password save error", err)
                return
              SendMail(req, res, "activate", user)
    else
      console.log("req.body is empty")
      res.statusCode = 400
      res.redirect("index")


  loginCallback: (req,res, user, info) ->
    if user
      console.log("we got a user")
      req.logIn user, (err) ->
        unless err
          console.log("we're in")
          req.flash('info', req.i18n.t('ns.msg:flash.' + info.message)\
          + info.data + " " + req.i18n.t('ns.msg:flash.' + info.message2))
          res.statusCode = 201
          res.redirect res.model.utils.object2URL(user)
        else
          console.log(5)
          console.log("inactiveuser")
          req.flash('info', req.i18n.t('ns.msg:flash.authorizationfailed'))
          res.statusCode = 403
          res.redirect "index"
    else
      console.log(4)
      req.flash('info', req.i18n.t('ns.msg:flash.' + info.message) + info.data + " " + req.i18n.t('ns.msg:flash.' + info.message2))
      res.statusCode = 403
      res.redirect "index"

  tokenCallback: (req, res, next) ->
    User._activate req.params.tokenstring, (err, user) ->
      console.log('end of activate')
      unless err
        console.log 'activate. user', user
        if user.provider.indexOf("local") == -1
          password = new Password({user:user._id})
          password.save (err, password)->
            if(err)
              console.log(err)
              next(err)
              return
            req.logIn user, (err) ->
              console.log('login err') if err
              next(err)  if err
              console.log("loggedin")
              req.flash('info', 'Please change your Password')
              utils.getAssociatedInstances req, req.user, (found, unfound)->
                for model of unfound
                  if(unfound._TandC)
                    res.statusCode = 201
                    res.redirect "authentication/tandc"
                    return
                res.redirect utils.object2URL(user)
        else
          res.statusCode = 400
          req.flash('info', req.i18n.t('ns.msg:flash.alreadyactivated'))
          req.logIn user, (err) ->
            console.log('login err') if err
            next(err)  if err
            console.log("loggedin")
            req.flash('info', 'Please change your Password')
            utils.getAssociatedInstances req, req.user, (found, unfound)->
              for model of unfound
                if(unfound._TandC)
                  res.statusCode = 201
                  res.redirect "authentication/tandc"
                  return
              res.redirect utils.object2URL(user)
      else if err is "token-expired-or-user-active"
        console.log "token-expired-or-user-active"
        res.statusCode = 403
        req.flash('info', req.i18n.t('ns.msg:flash.tokenexpires'))
        res.redirect "index"

    
  strategy: (url)->
    return new LocalStrategy 
      usernameField: "email",
      passwordField: "password"
    ,(email, password, done) ->
      console.log "local strategy"
      User.findOne email: email, (err, user) ->
        unless err
          if user
            Password.findOne user: user._id, (error, password_ob) ->
              unless err
                if password_ob
                  attempts = password_ob._loginAttempts
                  if ((5 - attempts) > 1)
                    remaining = "attemptsrem"
                  else
                    remaining = "attemptrem"
                  if password_ob.lockUntil < Date.now()
                    password_ob._comparePassword password, (err,isMatch)->
                      unless err
                        if isMatch
                          console.log "authorization success"
                          password_ob._resetLoginAttempts (cb) ->
                            done(null,user,
                              message: "authorizationsuccess"
                              data: "."
                              message2: "welcome")
                        else
                          if password_ob._loginAttempts < 5
                            console.log "pass not match"
                            password_ob._incLoginAttempts (cb)->
                              done(null,false,
                                message: "invalidpass",
                                data: ". " + (5 - attempts),
                                message2: remaining )
                          else
                            done(null,false,
                              message: "lockedafter",
                              data: attempts,
                              message2: "wrongattempts")
                      else
                        console.log "pass not match"
                        attempts = password_ob._loginAttempts
                        if password_ob._loginAttempts < 5
                          password_ob._incLoginAttempts (cb)->
                            done(null,false,
                              message: "invalidpass",
                              data: ". " + (5 - attempts),
                              message2: remaining )
                  else
                    console.log "user is locked"
                    date = new Date(user.lockUntil)
                    done(err,false,
                      message: "lockeduntil",
                      data: ": " + date + ".",
                      message2:"tryagainlater")
                else
                  console.log "user has not setup password login"
                  date = new Date(password_ob.lockUntil)
                  done("This User has not setup Login Password",false,
                    message: "",
                    data: ": " +  + ".",
                    message2:"tryagainlater")
          else
            console.log "user find error"
            done(err,false,
              message: "authorizationfailed",
              data: ".",
              message2: "tryagain")

