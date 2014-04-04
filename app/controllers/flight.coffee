FMs = require "../models/flight/models"
formidable = require "formidable"
config = require "../config/config"
csv = require "fast-csv"
engine = require '../config/engine'



engine.on 'join:/flight/index', (socket) ->
  return unless socket.user?.groups is 'admin'
  user2socket[socket.user.name] = socket
  user2socket[socket.user.name].on "close", ()->
    unset user2socket[socket.user.name]

  socket.on 'data', (data) ->
    console.log 'data', data
    try
      parsed = JSON.parse data
    catch e
      return socket.send "error: #{e.message}"


user2socket = {}
user2files = {}
csv_file_handler =
  prep: (req, name, file)->
    console.log file.type
    if file.type is "csv"
      user2files[req.user.name][name] =
        name: name
        max: 0
        total: 0
        rejected: 0
        duplicant: 0
        objects_per_row: 0
        added: 0
  handlePart: (req, part)->
    if !user2files[req.user.name][part.filename]
      return
    user2files[req.user.name][part.filename].max += part.split("\n").length
  upload: (req, file, row_handler)->
    stream = fs.createReadStream(file.path)
    error = (false)
    csv().fromStream(stream, {headers:true}).on("record", (data)->
      console.log(data)
      if(error)
        return
      row_handler data, (err, results)->
        if(err)
          if user2socket[req.user.name]
            user2socket[req.user.name].send JSON.stringify(err)
          error = err
          return
        user2files[req.user.name][file.name].rejected += results.rejected
        user2files[req.user.name][file.name].duplicant += results.duplicant
        user2files[req.user.name][file.name].added += results.added
        user2files[req.user.name][file.name].object_per_row = \
        results.objects_per_row
        user2files[req.user.name][file.name].total++
        if user2socket[req.user.name]
          user2socket[req.user.name].send \
          JSON.stringify({app:"CSV-uploader", data:user2files[req.user.name][file.name]})
      
    ).on("end", ()->
      console.log JSON.stringify(user2files[req.user.name][file.name])
      fs.unlink file.path, (err) ->
        console.log 'deleted', file.path
        cb err
    )

parse_row = (data, callback)->
  results =
    rejected:0
    duplicant:0
    addes:0
    objects_per_row : 8
  topic = 0
  lic = []
  rgn = 0
  cpy = 0
  ads = 0
  usr = 0
  error = (false)
  # I should check if topic even exsists before I start
  if data.topic_id == (null) || data.topic_id = ""
    return
  # I should probably define my functions
  # before I begin to avoid such callback hell
  
  # In case you didn't realize where you were, welcome to callback hell.
  #now featuring more scoping manipulation attempts
  FMs.topic.findOne {topic_id:data.topic_id}, (err, topic_a) ->
    if err
      results.rejected++
      callback(err)
      return
    if topic_a
      results.duplicates++
      topic = topic_a
    else
      topic = new FMs.topic {topic_id:data.topic_id, name:data.topic_name}
      topic.save (err, topic_a) ->
        if err
          results.rejected++
          error = err
          callback(err)
          return
        topic = topic_a
    lics = data.licences.split "\n"
    lic_funk = ()->
      if lics.length > 0
        temp = lics.pop()
        FMs.license.findOne {full_name:temp}, (err, lic_a) ->
          if err
            results.rejected++
            error = err
          else if lic_a
            results.duplicates++
            lic.unshift lic_a
            lic_funk()
          else
            parts = temp.split "("
            parts[0] = parts[0].substring(0,parts[0].length-2)
            parts[1] = parts[1].substring(0,parts[1].length-2)
            lic.unshift new FMs.license \
            {full_name:temp,abr:parts[1],name:parts[0]}
            lic[0].save (err, lic_a) ->
              if err
                results.rejected++
                error = err
              else
                lic[0] = lic_a
              lic_funk()
      else
        regions = [data.region, data.post_town, data.county]
        parent = (null)
        
        region_funk = ()->
          if regions.length > 0
            temp = regions.pop()
            FMs.region.findOne {name: temp, level: regions.length,\
            parent: parent}, (err, region_a) ->
              if err
                results.rejected++
                error = err
              else if region_a
                results.duplicates++
                if(regions.length == 0)
                  rgn = region_a
                else
                  parent = region_a
                region_funk()
              else
                saved = new FMs.region {name: temp, level: \
                regions.length, parent:parent}
                
                if(parent != null)
                  saved.parent = parent._id
                saved.save (err, saved_a) ->
                  if(err)
                    results.rejected++
                    error = err
                  if(regions.length == 0)
                    rgn = saved_a
                  if(parent != null)
                    parent.children.push saved_a._id
                    parent.save (err) ->
                      if err
                        results.rejected++
                        error = err
                      region_funk()
                  else
                    region_funk()
          else if(topic != 0)
            FMs.company.findOne {name: data.company_name, \
            topic: topic._id}, (err, cpy_a) ->
              if err
                results.rejected++
                error = err
                callback err
                return
              new_lic = []
              if cpy_a
                results.duplicates++
                if(cpy_a.topic == null || cpy_a.topic == "")
                  cpy_a.topic = topic._id
                else if(cpy_a.topic != topic._id)
                  throw new Error "different topics"
                if(cp_a.url == null || cpy_a.url == "")
                  cpy_a.url = data.url
                `
                  var cpyll = cpy_a.license.length
                  for(lic_i in lic){
                    var tempbool = true;
                    for(var i=0;i<cpy11;i++)
                      if(cpy_a.license[i] == lic[lic_i]._id){
                        tempbool = false;
                        break;
                      }
                    if(tempbool){
                      cpy_a.license.push(lic[lic_i]._id);
                      new_lic.push(lic[lic_i]);
                    }
                  }
                `
                cpy = cpy_a
              else
                lic_ids = []
                if(lic.length > 0)
                  lic_ids.push lic_i._id for lic_i in lic
                cpy = new FMs.company
                  name: data.company_name
                  url:data.url
                  topic: topic._id
                  license: lic_ids
                  logo_url: data.logo_URL
                new_lic = lic
              lic_done = new_lic.length-1
              cpy.save (err, cpy_b)->
                if(err)
                  results.rejected++
                  error = err
                  callback err
                  return
                cpy = cpy_b
                lic_save = ()->
                  new_lic[lic_done].companies.push cpy._id
                  new_lic[lic_done].save (err,lic_a)->
                    if err
                      results.rejected++
                      error = err
                      callback err
                      return
                    lic_done--
                    if lic_done > -1
                      lic_save()
                    else
                      FMs.address.findOne {\
                      address: data.address
                      , post_code: data.post_code
                      , company: cpy._id
                      , region: rgn._id\
                      }, (err, add_a)->
                        if(err)
                          results.rejected++
                          error = err
                          return
                        if add_a
                          results.duplicates++
                          callback(null, results)
                          return
                        else
                          tp = data.telephone.replace(/\D/g,'')
                          fx = data.fax_number.replace(/\D/g,'')
                          ads = new FMs.address {\
                          address: data.address
                          , post_code: data.post_code
                          , telephone_number: tp
                          , fax_number: fx
                          , email: data.email
                          , company: cpy._id
                          , region: rgn._id
                          , users: []\
                          }
                          ads.save (err, ads_a)->
                            if err
                              results.rejected++
                              error = err
                              callback err
                              return
                            cpy.addresses.push ads_a._id
                            cpy.save (err, cpy_a)->
                              if err
                                results.rejected++
                                error = err
                                callback err
                                return
                              rgn.addresses.push ads_a._id
                              rgn.save (err, rgn_a)->
                                if err
                                  results.rejected++
                                  error = err
                                  callback err
                                  return
                                else
                                  callback(null,results)

# flight model's CRUD controller.
Route =
  # Lists all Companies
  index: (req, res) ->
    FMs.company.find {}, (err, companies) ->
      res.render "flight/flight-template",
        view : "index"
        user : req.user
        companies : companies
        uploads : user2files[req.user.name]
  upload: (req, res)->
    if req.method is 'POST'
      if !req.user || req.user.groups isnt 'admin'
        return res.send(403)
      body = req.body
      if !body?
        return res.send 400, 'Must provide data.'
      action = body.action || req.query.action
      return res.send 400, 'Must provide valid action type.' unless action
      if action is "upload"
        form = new formidable.IncomingForm
        form.uploadDir = config.UPLOADS
        form.on "filebegin", (name, file)->
          csv_file_handler.prep req, name, file
        form.onPart = (part) ->
          # reject any unexpected file, to prevent exploit.
          if part.filename and part.name isnt 'file'
            console.log 'rejected', part.name, part.filename
            return
          csv_file_handler.handlePart req, part
          form.handlePart(part)
        form.parse req, (err, fields, files) ->
          file = files?.file
          console.log 'uploaded', err, file?.name, file?.path
          return res.send 500, err.message || err if err
          return res.send 200 unless file
          
          csv_file_handler req, file, parse_row for filename, file of files
        FMs.company.find({}).populate('topic').exec (err, companies) ->
          res.render "flight/company", {companies : companies}
      else
        return res.send 400, 'Must provide valid action type.' unless action



module.exports = Route
