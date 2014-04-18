GoogleStrategy = require("passport-google").Strategy
User = require("../models/user/user")

module.exports = 
  authCallback: true
  strategy: (url)->
    return new GoogleStrategy
      returnURL: url + "/authenticate/google/callback"
      realm: url
      stateless: true
    , (token, profile, done) ->
      console.log "arguments in google strategy"
      console.log profile.emails
      console.log profile
      emails = []
      for mail in profile.emails
        emails.push mail.value
      User.findOneAndUpdate(
        "email": {$in: emails}
      ,
        $addToSet:
          "provider": "google"
      ,(err, user) ->
        if err? then return done err, null,
          message: "authorizationfailed",
          data: ".",
          message2: "tryagain"
        unless user
          User.create(
            "email": emails[0]
            "provider": ["google"]
            "name": profile.name.givenName
            "surname": profile.name.familyName
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
          unless err
            if err? then return done err, null,
              message: "authorizationfailed",
              data: ".",
              message2: "tryagain"
            done null, user,
              message: "authorizationsuccess"
              data: "."
              message2: "welcome"
      )