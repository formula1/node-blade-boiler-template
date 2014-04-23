utils = require ("./utils.coffee")

module.exports =
  create: (req, res, model, params, next) ->
    utils.parse_params model, params, (err, topass) ->
      ret_err = []
      if err
        console.log(JSON.stringify(err))
        ret_err.concat err
        next ret_err, topass
        return
      model.create topass, (err, instance) ->
        if err
          ret_err.push err
          next ret_err, topass
          return
        instance._createHook req, res, (err) ->
          if err
            ret_err.push err
            next ret_err, topass
          else
            ret_err = undefined
            next ret_err, instance
          return
      return
    return

  search: (model, params, another, next) ->
    ret_err = undefined
    if another is null
      ret_err = []
      utils.req_parse_params model, params, (err, topass) ->
        ipp = undefined
        key = undefined
        page = undefined
        path = undefined
        paths = undefined
        sort = undefined
        to_pop = undefined
        if err
          ret_err.push err
          next ret_err, topass
          return
        paths = model.schema.paths
        to_pop = ""
        for key of paths
          path = paths[key]
          if key isnt "_id"
            if path.caster
              to_pop += path.path + " "  if path.caster.instance is "ObjectID"
            else to_pop += path.path + " "  if path.instance is "ObjectID"
        to_pop = to_pop.substring(0, to_pop.length - 1)  if to_pop isnt ""
        console.log topass
        sort = topass._sort
        delete topass._sort

        page = topass._page
        delete topass._page

        console.log "IPP: " + topass.ipp
        ipp = topass._ipp
        delete topass._ipp

        model.find(topass).sort(sort).skip(page * ipp).limit(ipp).populate(to_pop).exec (err, instances) ->
          if err
            ret_err.push err
            next ret_err, topass
            return
          ret_err = undefined
          next ret_err,
            params: topass
            docs: instances
    else if another.toUpperCase() is "delete"
      utils.req_parse_params model, params, (err, topass) ->
        if err
          ret_err.push err
          next ret_err, topass
          return
        model.find topass, (err, instances) ->
          if err
            ret_err.push err
            next ret_err, topass
            return
          ret_err = undefined
          next ret_err,
            params: topass
            docs: instances
    else if another.toLowerCase() is "update"
      utils.req_parse_params model, params, (err, topass) ->
        if err
          ret_err.push err
          next ret_err, topass
          return
        model.find topass, (err, instances) ->
          if err
            ret_err.push err
            next ret_err, topass
            return
          ret_err = undefined
          next ret_err,
            params: topass
            docs: instances
  update: (req, res, instance, params, next) ->
    console.log("here")
    utils.update_parse_params instance._getModel(), params, (err, topass) ->
      console.log("topass:"+JSON.stringify(topass))
      model = instance._getModel()
      ret_err = []
      if err
        console.log JSON.stringify(err)
        ret_err.concat err
        next ret_err, topass
        return
      find = {}
      find[model._getDocSlug()] = instance[model._getDocSlug()]
      console.log(JSON.stringify(find))
      model.findOne find, (err, instance) ->
        if err
          throw new Error(err)
          ret_err.push err
          next ret_err, topass
          return
        if(instance)
          console.log("instance")
          for key, value of topass
            instance[key] = value
          instance.save (err)->
            if err
              console.log(JSON.stringify(err))
              ret_err.push err
              next ret_err, topass
            else
              ret_err = undefined
              next ret_err, instance
        else
          ret_err.push "This document does not exist"
          next ret_err, topass
  delete: ->
  method: (req,res,doc, method,query, next)->
    argsnames = utils.getArgs(doc[method])
    argvalues = []
    ret_err = []
    for name in argsnames
      if(query[name])
        argvalues.push query[name]
      else if(name.match(/req|request|res|response|next|cb|callback/))
        continue
      else
        ret_err.push { message:"need all arguments for the method: "+method}
        next ret_err, argvalues
        return
    if(argsnames[1].match(/res|response/))
      argvalues.unshift res
    if(argsnames[0].match(/req|request/))
      argvalues.unshift req
    if(argsnames[argsnames.length-1].match(/next|cb|callback/))
      argvalues.push (errors, data, render)->
        if(errors)
          if(Object.prototype.toString.call( errors ) == '[object Array]')
            ret_err.concat errors
          else 
            ret_err.push errors
          next ret_err, argvalues, render
          return
        next(null,data, render)
    doc[method].apply(doc, argvalues)
