### Models
# Used to simplify CRUD interactions with mongoose
#
# function names to avoid
# -validateUser
# -getModelTitle
# -getDocSlug
# -getDocTitle
#
###

mongoose = require "mongoose"



User = require "../models/user/user"
formidable = require "formidable"
fs = require "fs"
logger = require "../utils/logger"
logCat = "USER controller"
validationEmail = /^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/
csv = require "fast-csv"



user_validation = (model, user, next)->
  if(model.userValidation)
    model.userValidation user, next
  else
    next (req.user and req.user.groups is 'admin')


parse_params = ( model, params, next)->
  #I should also make it validate path types
  #or not at all, we will see...
  required = model.schema.requiredPaths()
  topass = {}
  for key, value of params
    if model.pathType(key) == "virtual"
      continue;
    else if model.pathType(key) == "adhocOrUndefined"
      continue
    else if model.pathType(key) == "nested"
      console.log "we're not ready for this yet"
      continue
    else if model.pathType(key) == "real"
      if(required.indexOf(key) == -1)
        topass[key] = value
      else if(value != "")
        required.splice(required.indexOf(key), 1)
  if(required.length > 0)
    if(!err) err = []
    for key, value of required
      err.push {name:value, message:"Missing a required value:"+value}
  process.nextTick ()->
    next(err, topass)

req_parse_params = ( model, params, next)->
  #I should also make it validate path types
  #or not at all, we will see...
  indexes = model.schema.indexes()
  si = []
  topass = {}
  toRegex = []
  toLoose = []
  err = []
  for key, value of params
    if model.pathType(key) == "virtual"
      continue;
    else if model.pathType(key) == "adhocOrUndefined"
      if key == "regex"
        try
          toRegex = JSON.parse value
        catch
          err.push {name:"Regex", message: "The Regex Parameter is not Properly Formatted" }
      if key == "loose"
        try
          toLoose = JSON.parse value
        catch
          err.push {name:"Loose", message: "The Loose Parameter is not properly formatted" }
      continue
    else if model.pathType(key) == "nested"
      console.log "we're not ready for this yet"
      continue
    else if model.pathType(key) == "real"
      if((temp = required.indexOf(key)) == -1)
        topass[key] = value
      else if(value != "")
        si.push key
        indexes.splice(temp, 1)
  for key of toRegex
    topass[key] = new RegEx(topass[key])
    if (temp = is.indexOf(key)) != -1
      is.splice(temp,1)
  for key of toLoose
    topass[key] = new RegEx("*"+topass[key]+"*")
    if (temp = is.indexOf(key)) != -1
      is.splice(temp,1)
  if(is.length == 0)
    err.push {name:value, message:"You should search by an index:"+value}
    
  if err.length == 0
    err = (null)
  process.nextTick ()->
    next(err, topass)

    
isNumber = (o) >
  return ! isNaN (o-0) && o !== null && o.replace(/^\s\s*/, '') !== "" && o !== false;
    
CRUD = 
  #Class
  #-Create Instance
  #-Search and Request|Update|Delete
  #-(Static Methods)
  create: (model, params, next)->
    for key, value in param
      attempt = param.split - 
      if(attempt > 1)
        db.users.find({"name": /.*m.*/})
    parse_params model, params, (err, topass)->
      ret_err = []
      if(err)
        ret_err.push err
        next(ret_err, topass)
        return
      instance = new model(topass)
      instance.save (err, instance)->
        if err
          ret_err.push err
          next err, topass
        else
          next null, instance
        
  request:(model, params, and, next)->
    if(and == null)
      # additionally need sort parameter
      # Also need pagination
      ret_err = []
      req_parse_params model, params, (err, topass)->
        if(err)
          ret_err.push err
          next ret_err topass
          return
        model.find topass, (err, instances)->
          if(err)
            ret_err.push err
            next ret_err topass
            return
          next null {params:topass, docs:instances}
    else if(and.toUpperCase() == "delete")
      # need to consider if they are just IDS
      #I'm not going to pass a regex to search for IDs, thats rediculous
      req_parse_params model, params, (err, topass)->
        if(err)
          ret_err.push err
          next ret_err topass
          return
        model.find topass, (err, instances)->
          if(err)
            ret_err.push err
            next ret_err topass
            return
          next null {params:topass, docs:instances}
    else if(and.toUpperCase() == "update")
      # need to consider if they are just IDS
      req_parse_params model, params, (err, topass)->
        if(err)
          ret_err.push err
          next ret_err topass
          return
        model.find topass, (err, instances)->
          if(err)
            ret_err.push err
            next ret_err topass
            return
          next null {params:topass, docs:instances}
      
  method: (doc, method,query, next)->
    argsnames = getParamNames(doc[method])
    argvalues = []
    ret_err = []
    for name in argsnames
      if(value == query[name])
        argvalues.push value
      else if(name.match(/next|cb|callback/))
        continue
      else
        ret_err.push { message:"need all arguments for the method: "+method}
        next ret_err argvalues
        return
    argvalues.push (err, data)->
      if(err)
        ret_err.push err
        next ret_err argvalues
        return
      next(null,data)
    doc[method].apply(doc, argvalues)
  
getParamNames =(func)->
  fnStr = func.toString().replace(STRIP_COMMENTS, '')
  result = fnStr.slice(fnStr.indexOf('(')+1, fnStr.indexOf(')')).match(/([^\s,]+)/g)
  if( result === null)
     result = []
  return result


renderClass = (model, code, path)->
  
  res.statusCode = code
  res.render(path)
  return

renderInstance = ()->
  return

# User model's CRUD controller.
Route =
  # Lists all users
  index: (req, res) ->
    mongoose.connection.db.collectionNames((err, names)->
      to_export = []
      db_funk = ()->
        if names.length > 0
          name = names.pop()
          name = name.name.split "."
          name = name[1]
          model = mongoose.model("name");
          mi = {slug: name, title: model.getModelTitle(), path: "/models/"+name, }
          if(model.validateUser)
            model.validateUser req.user, (valboo)->
              if valboo
                model.count (err, count)->
                  if err
                    req.flash('info', req.i18n.t('ns.msg:flash.dberr') + error.message)
                    db_funk()
                    return
                  mi.count = count
                  to_export.push mi
                process.nextTick ()->
                  db_funk()
              else
                process.nextTick ()->
                  db_funk()
          else
            model.count (err, count)->
              if err
                req.flash('info', req.i18n.t('ns.msg:flash.dberr') + error.message)
                db_funk()
                return
              mi.count = count
              to_export.push mi
                process.nextTick ()->
                  db_funk()
        else
          res.locals.model.models = to_export
          res.render "/models/index"
          return
      db_funk()
    )

    
  all:  (req, res) ->
    mongoose.connection.db.collectionNames( (err, names)->
      for key, value of names
        if(req.params.method == value)
          model = mongoose.model(value)
          locals.model.model = model
          user_validation model, req.user, (validboo)->
            if(validboo)
              params
              if(req.method.toUpperCase() == "GET")
                params = req.query
              else if(req.method.toUpperCase() == "POST")
                params = req.body
              patharray = req.pathname.split "/"
              method = patharray[2]
              if(!patharray[2])
                CRUD.request model, {}, null, renderClass, (err, ret)->
                  if(err)
                    for key, value of err
                      req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err.message)
                    res.locals.model.request = ret
                    res.locals.model.instances = []
                    res.render("models/model")
                    return
                  res.locals.model.request = ret.params
                  res.locals.model.instances = ret.docs
                  res.render("models/model")
                  
              else if(patharray[2].indexOf("search") == 0)
                another = patharray[2].split "-"
                if(another.length > 1)
                  another = another[1]
                else
                  another = (null)
                CRUD.request model, params, another, (err, ret)->
                  if(err)
                    for key, value of err
                      req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err.message)
                    res.locals.model.request = ret
                    res.locals.model.instances = []
                    res.render("models/model")
                    return
                  res.locals.model.request = ret.params
                  res.locals.model.instances = ret.docs
                  res.render("models/model")
              else if(patharray[2] == "create")
                CRUD.create model, params, (err, ret)->
                  if(err)
                    for key, value of err
                      req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err.message)
                    res.locals.model.form.tocreate = ret
                    res.render("models/model")
                    return
                  res.locals.model.instance = ret
                  res.locals.model.schema = model.schema
                  res.statusCode = 200
                  res.redirect("models/"+model.modelName+"/"+instance.get(instance.slug))
              else
                schema = model.schema
                if(key == "validateUser")
                  req.flash('info', req.i18n.t('ns.msg:flash.dberr') + "Non Exsistant Method")
                  res.statusCode = 404
                  res.locals.model.params = params
                  res.render("models/model")
                for key, value of schema.statics
                  if(key.match("validateUser|docSlug|docTitle|modelTitle")
                    continue
                  if(patharray[2] == key)
                    CRUD.method model,key,req.query, renderClass, (err, data)->
                      if(err)
                        for key, value of err
                          req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
                        res.locals.model.model[key] = ret
                        res.render("models/model")
                        return
                      res.locals.model[key] = data
                      res.render("models/model")
                    return
                find = {}
                find[model.instanceSlug()] = patharray[2]
                model.find find, (err,docs)->
                  if(err)
                    req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
                    res.model = model
                    res.render("models/model")
                  if(docs.length == 0)
                    req.flash('info', req.i18n.t('ns.msg:flash.dberr') + "this "+model.modelName+" does not exist")
                    res.statusCode = 404
                    res.render("models/model")
                  doc = docs[0]
                  res.locals.model.instance = doc
                  if(!patharray[3] || patharray[3] = "")
                    res.render("models/instance")
                  else if(patharray[3] == "update")
                  else if(patharray[3] == "delete")
                  else
                    schema = model.schema
                    for key, value of schema.methods
                      if(patharray[3] == key)
                        CRUD.method doc,key,req.query, renderClass, (err, data)->
                          if(err)
                            for key, value of err
                              req.flash('info', req.i18n.t('ns.msg:flash.dberr') + err)
                            res.locals.model.forms[key].args = ret
                            res.render("models/instance")
                            return
                          res.locals.model.forms[key].data = data
                          res.render("models/instance")
                        return
                    req.flash('info', req.i18n.t('ns.msg:flash.dberr') + "This method does not exist")
                    res.statusCode = 404
                    res.redirect("models/instance")
            else
              req.flash('info', req.i18n.t('ns.msg:flash.dberr') + "You don't have access")
              res.statusCode = 403
              res.redirect("models/index")
          return
      req.flash('info', req.i18n.t('ns.msg:flash.dberr') + "Non Exsistant Model")
      res.statusCode = 404
      res.redirect("models/index")
    );

module.exports = Route
