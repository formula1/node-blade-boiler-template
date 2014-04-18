LocalStrategy = require('passport-local').Strategy
Password = require('../models/user/password')
User = require("../models/user/user")

module.exports = 
  loginCallback: (req,res, user, info) ->
    if user
      req.logIn user, (err) ->
        unless err
          req.flash('info', req.i18n.t('ns.msg:flash.' + info.message) + info.data + " " + req.i18n.t('ns.msg:flash.' + info.message2))
          res.statusCode = 201
          res.redirect '/user/get'

        else
          console.log(5)
          console.log("inactiveuser")
          req.flash('info', req.i18n.t('ns.msg:flash.authorizationfailed'))
          res.redirect "index"
          res.statusCode = 403
    else
      console.log(4)
      req.flash('info', req.i18n.t('ns.msg:flash.' + info.message) + info.data + " " + req.i18n.t('ns.msg:flash.' + info.message2))
      res.statusCode = 403
      res.redirect "index"

  tokenCallback: (req, res, next) ->
    Password.activate req.params.token, (err, user) ->
      console.log('end of activate')
      unless err
        console.log 'activate. user', user
        if user.active is true
          req.logIn user, (err) ->
            console.log('login err') if err
            next(err)  if err
            req.flash('info', 'Activation success')
            res.redirect "user/resetpassword/" + user.tokenString
        else
          res.statusCode = 400
          req.flash('info', req.i18n.t('ns.msg:flash.alreadyactivated'))
          res.redirect "index"
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
            if user.active is true
              Password.findOne user: user._id, (error, password) ->
                unless err
                  if password
                    attempts = password.loginAttempts
                    if ((5 - attempts) > 1)
                      remaining = "attemptsrem"
                    else
                      remaining = "attemptrem"
                    if user.lockUntil < Date.now()
                      password.comparePassword password, (err,isMatch)->
                        unless err
                          if isMatch
                            console.log "authorization success"
                            password.resetLoginAttempts (cb) ->
                              done(null,user,
                                message: "authorizationsuccess"
                                data: "."
                                message2: "welcome")
                          else
                            if user.loginAttempts < 5
                              console.log "pass not match"
                              password.incLoginAttempts (cb)->
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
                          attempts = password.loginAttempts
                          if password.loginAttempts < 5
                            password.incLoginAttempts (cb)->
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
              done(null, false,
                message: "inactiveuser",
                data: ". ",
                message2:"requestlinkagain")
          else
            console.log "user find error"
            done(err,false,
              message: "authorizationfailed",
              data: ".",
              message2: "tryagain")