#
# User model
# Ideas from http://blog.mongodb.org/post/32866457221/password-authentication-with-mongoose-part-1
# and http://devsmash.com/blog/implementing-max-login-attempts-with-mongoose
#

mongoose = require "mongoose"
crypto = require "crypto"
base64url = require "base64url"
sanitize = require("validator").sanitize
messages = require "../../utils/messages"
rmv = require "../../utils/m-schema-layer.coffee"
autoIncrement = require('mongoose-auto-increment');
utils = require "../../controllers/model/utils"

autoIncrement.initialize(mongoose.connection);


SALT_WORK_FACTOR = 10
# default to a max of 5 attempts, result in a 2 hour lock
MAX_LOGIN_ATTEMPTS = 5
LOCK_TIME = 2 * 60 * 60 * 1000
# token alive time is 24 hours
TOKEN_TIME = 24 * 60 * 60 * 1000

# Database schema
Schema = mongoose.Schema

# User Groups schema
#UserGroupSchema = new Schema(
#  name:
#    type: String
#    required: true
#    index:
#      unique: true
#    default: "guest"
#  group:
#    type: "ObjectId"
#)

# User schema
UserSchema = rmv(
  email:
    type: String
    unique: true
    match: /^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/
    # index:
  name:
    type: String
    required: false
    default: 'user'
  surname:
    type: String
    required: false
    default: ''
  #groups: [UserGroupSchema]
  groups: # [guest, member, reviewer, admin]
    type: String
    enum: ["guest", "member", "reviewers", "admin"]
    default: "guest"

  tokenString:
    type: String

  tokenExpires:
    type: Number

  provider:
    type: Array
    enum: ["facebook", "google", "yahoo", "local", "github", "persona", "linkedin", "twitter"]
    required: false
  slug:
    type: Number
  docSlug: "slug"
)

# expose enum on the model, and provide an internal convenience reference
# TODO: replace the error message with this enum, then show messages from views


# Bcrypt middleware
UserSchema.pre "save", (next) ->
  user = this

  # Reset changepassword token.
  user.resetToken (err) ->
    return next err if err
    next()


UserSchema.methods.resetToken = (next) ->
  user = @
  crypto.randomBytes 48, (ex, buf) ->
    return next ex if ex
    user.tokenString = base64url buf
    user.tokenExpires = Date.now() + TOKEN_TIME
    next()


# Static methods
# Register new user
UserSchema.statics.register = (user, cb) ->
  self = new this(user)
  user.email = sanitize(user.email.toLowerCase().trim()).xss()
  validator.check(user.email, messages.VALIDATE_EMAIL).isEmail()
  errors = validator.getErrors()
  if errors.length
    errorString = errors.join("<br>")
    return cb(errorString)
    console.log "Registration form failed with " + errors
    #go to the signup page
    return cb(errorString, null)
  else
    @findOne
      email: user.email
    , (err, existingUser) ->
      return cb(err)  if err
      return cb("user-exists")  if existingUser
      self.save (err) ->
        return cb(err) if err
        cb null, self

# Activate new user
UserSchema.statics._activate = (token, cb) ->
  @findOne
    tokenString: token
  , (err, existingUser) ->
    return cb(err)  if err
    if existingUser
      if existingUser.tokenExpires > Date.now()
        existingUser.groups = "member"
        existingUser.save (err, user)->
          unless err
            cb null, user
          else
            cb "save error"
      else
        cb "token-expired"
    else
      cb "token-expired-or-user-active"

UserSchema.method "__getAssociated", (req, callback)->
  utils.getAssociatedInstances req,this, (found, unfound)->
    this.associated = found
    this.tandc = []
    for model of unfound
      if(model.TermsAndConditions)
        this.tandc.push model.TermsAndConditions()
    if(this.tandc.length == 0)
      delete this.tandc
    user = this
    process.nextTick ()->
      callback(user)
      
UserSchema.plugin(autoIncrement.plugin, { model: 'user', field: 'slug' });

module.exports = mongoose.model 'user', UserSchema

