crud = require "../controllers/model/crud.coffee"
utils = require "../controllers/model/utils.coffee"
mongoose = require "mongoose"

module.exports = 
  finishTandC: (req, res, next)->
    res.plugin.redirect = "/company/"
    next(undefined, req,res)
  preRender: (req, res, next)->
    if(req.params.model.match("company_address|company_region"))
      res.locals.model.inputRender = "location"
      res.locals.model.viewRender = "location"
      if(req.params.hasOwnProperty("instance"))
        cur_region = res.locals.model.instance.region
        region_populate = ()->
          cur_region.populate("parent").exec (err, region)->
            res.locals.model.nested[region.parent._id] = region.parent
            if(region.parent != null)
              cur_region = region.parent
              region_populate()
            else
              next(undefined, req,res)
        region_populate()
    next(undefined, req,res)
  preRedirect: (req, res, next)->
    if(req.params.model == "company")
      console.log("we're in there"+JSON.stringify(req.params))
      for key, value of req.params
        console.log(key)
      if(req.params.hasOwnProperty("method") && req.params.method == "create")
        req.flash("info", "Please add your Address")
        res.plugin.redirect = "/company_address/"
    if(req.params.model == "company_address")
      if(req.params.hasOwnProperty("method") && req.params.method == "create")
        req.flash("info", "You have setup your Company! now you may invite add users or more addresses")
        res.plugin.redirect = "/company/"
    next(undefined, req,res)
  preData: (req, res, next)->
    if(req.params.model != "company_address")
      return next()
    if(!req.params.hasOwnProperty("method") || req.params.method != "create")
      return next()
    if(!req.hasOwnProperty("user") || !req.user.associated.hasOwnProperty("company_id"))
      return next("The User needs to agree to Terms and Conditions")
    if(req.user.associated.company_id.company == null)
      return next("The User needs to create a company first")
    query = {}
    if(req.method.toUpperCase() == "GET")
      query = req.query
    else if(req.method.toUpperCase() == "POST")
      query = req.body
    else
      return next()
    company = req.user.associated.company_id.company
    console.log("Address Company: "+company)
    region = mongoose.model("company_region")
    country = query.country
    region_names = 
      2: query.region_0
      1: query.region_1
      0: query.region_2
    level = 0
    parent = undefined
    create_region = ()->
      if(level > 2)
        console.log("Address Company: "+company)
        console.log("Address Region: "+parent)
        if(req.method.toUpperCase() == "GET")
          req.query.region = parent
          req.query.company = company
        else if(req.method.toUpperCase() == "POST")
          req.body.region = parent
          req.body.company = company
        next(undefined, req, res)
      params = {country:country,level:level}
      params.name = region_names[level]
      if(params.name == "")
        level++
        process.nextTick ()->
          create_region()
        return
      if(parent != undefined)
        params.parent = parent
      crud.create req,res, region, params, (err, ri)->
        if(err)
          for key, value of err
            req.flash 'info'
            , JSON.stringify(value)
          return
        parent = ri._id
        level++
        process.nextTick ()->
          create_region()
    create_region()
