YahooStrategy = require("passport-yahoo").Strategy
User = require("../models/user/user")

module.exports =
  authCallback: true
  strategy: (url)->
    return new YahooStrategy
      returnURL: url + "/authenticate/yahoo/callback"
      realm: url
    , (identifier, profile, done) ->
      emails = []
      for mail in profile.emails
        emails.push mail.value
      console.log "arguments in yahoo strategy"
      console.log profile.emails
      console.log profile
      displayName = profile.displayName.split(" ")
      User.findOneAndUpdate(
        "emails": {$in: emails}
      , $addToSet:
        "provider": "yahoo"
      , (err, user) ->
        if err? then return done err, null,
          message: "authorizationfailed",
          data: ".",
          message2: "tryagain"
        unless user
          User.create(
            "email": emails[0]
            "provider": ["yahoo"]
            "name": displayName[0]
            "surname": displayName[1]
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