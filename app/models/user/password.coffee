bcrypt = require "bcrypt"
mongoose = require "mongoose"
Schema = mongoose.Schema
rmv = require "../../utils/m-schema-layer.coffee"
User = require "./user.coffee"
crypto = require "crypto"
crypto = require "crypto"
base64url = require "base64url"

SALT_WORK_FACTOR = 10
# default to a max of 5 attempts, result in a 2 hour lock
MAX_LOGIN_ATTEMPTS = 5
LOCK_TIME = 2 * 60 * 60 * 1000
# token alive time is 24 hours
TOKEN_TIME = 24 * 60 * 60 * 1000


password = rmv(
  user:
    type: Schema.Types.ObjectId
    ref: "user"
    required: true
  password:
    type: String
    required: true
    default: base64url(crypto.randomBytes 48)
  _loginAttempts:
    type: Number
    default: 0
  lockUntil:
    type: Number
    default: 0
  active:
    type:Boolean
    default:false
  validateRequest: (req, mi, method, next) ->
    if(mi instanceof mongoose.Document && req.user)
      console.log("valid?"+(mi.user.toString() == req.user._id.toString()))
      next(mi.user.toString() == req.user._id.toString())
    else
      next(false)
,
  associatedTo: "user"
)

password.statics.failedLogin =
  NOT_FOUND: 0
  PASSWORD_INCORRECT: 1
  MAX_ATTEMPTS: 2
  INACTIVE: 3
  TOKEN_UNMATCH: 4
  TOKEN_EXPIRES: 5


password.virtual("isLocked").get ->
  # check for a future lockUntil timestamp
  !!(@lockUntil and @lockUntil > Date.now())

password.pre "save", (next)->
  return next() unless this.isModified("password")
  # generate a salt
  password = this
  bcrypt.genSalt SALT_WORK_FACTOR, (err, salt) ->
    return next(err)  if err

    # hash the password along with our new salt
    bcrypt.hash password.password, salt, (err, hash) ->
      return next(err)  if err

      # override the cleartext password with the hashed one
      password.password = hash
      next()


password.post "save", (doc)->
  User.update {_id:doc.user}, {$addToSet: {provider:"local"}}, (err)->
    if(err)
      console.log("user save error in password")

password.method "_incLoginAttempts", (next)->
  #if we have a previous lock that has expired, restart at 1
  if @lockUntil and @lockUntil < Date.now()
    return @update(
      $set:
        loginAttempts: 1

      $unset:
        lockUntil: 1
    , next)

  # otherwise were incrementing
  updates = $inc:
    loginAttempts: 1

  # lock the user if we've reached max attempts and it's not locked already
  updates.$set = lockUntil: Date.now() + LOCK_TIME  if @loginAttempts + 1 >= MAX_LOGIN_ATTEMPTS and not @isLocked
  @update updates, next

password.method "_resetLoginAttempts", (next)->
  #if we have a previous lock that has expired, restart at 1
  if @lockUntil and @lockUntil < Date.now()
    return @update(
      $set:
        loginAttempts: 0
    , next)

  # reset login attempts to zero
  updates = $set:
    loginAttempts: 0

  @update updates, next

password.method "_comparePassword", (userPassword, next) ->
  bcrypt.compare userPassword, @password, (err, isMatch) ->
    return next(err)  if err
    next null, isMatch
    
    
module.exports = mongoose.model 'password', password