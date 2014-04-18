PersonaStrategy = require("passport-persona").Strategy
User = require("../models/user/user")


module.exports =
  strategy: (url)->
    return new PersonaStrategy
      audience: url
    , (email, done) ->
      # console.log "arguments in persona strategy"
      # console.log profile
      process.nextTick ->
        User.findOneAndUpdate(
          "email": email
        , $addToSet:
          "provider": "persona"
        , (err, user) ->
          if err? then return done err, null,
            message: "authorizationfailed",
            data: ".",
            message2: "tryagain"
          unless user
            User.create(
              "email": email
              "provider": "persona"
              "name": email
              "active": true
              "groups": "member"
            , (err,newUser)->
              if err? then return done err, null,
                message: "authorizationfailed",
                data: ".",
                message2: "tryagain"
              done null, newUser,
                message: "authorizationsuccess"
                data: "."
                message2: "welcome"
            )
          else
            done null, user,
              message: "authorizationsuccess"
              data: "."
              message2: "welcome"
        )