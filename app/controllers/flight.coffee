FMs = require "../models/flight/models"
formidable = require "formidable"
config = require "../config/config"
csv = require "fast-csv"
engine = require '../config/engine'
fs = require 'fs'



engine.on 'join:/flight', (socket) ->
  console.log("are we here?")
  throw new Error("stopping point")
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
    console.log "FILE TYPE"+file.type
    nari = file.name.split(".")
    console.log file.type is "text/plain"
    console.log nari.length > 1
    console.log "csv" == nari[1]
    if file.type is "text/plain" && nari.length > 1 && "csv" == nari[1]
      if(!user2files[req.user.name])
        user2files[req.user.name] = {}
      user2files[req.user.name][file.name] =
        name: file.name
        max: 0
        total: 0
        rejected: 0
        duplicant: 0
        objects_per_row: 0
        added: 0
      return (true)
    else 
      return (false)
  handlePart: (req, part)->
    if !user2files[req.user.name] || !user2files[req.user.name][part.filename]
      return
    user2files[req.user.name][part.filename].max += part.split("\n").length
  upload: (req, file, row_handler)->
    error = (false)
    console.log key for key,value of css
    username = req.user.name
    filename = file.name
    filepath = file.path
    csv.fromPath(filepath, {headers:true}).on("record", (data)->
      row_handler data, (err, results)->
        if(err)
          if user2socket[username]
            user2socket[username].send \
            JSON.stringify({app:"CSV-uploader",error:err})
        user2files[username][filename].rejected += results.rejected
        user2files[username][filename].duplicant += results.duplicant
        user2files[username][filename].added += results.added
        user2files[username][filename].object_per_row = \
        results.objects_per_row
        user2files[username][filename].total++
        if user2socket[username]
          user2socket[username].send \
          JSON.stringify({app:"CSV-uploader", data:user2files[username][filename]})
      
    ).on("end", ()->
      console.log JSON.stringify(user2files[username][filename])
      fs.unlink filepath, (err) ->
        if(err) 
          console.log("controller/flight-81:"+err)
        else
          console.log 'deleted', file.path
    )

parse_row = (data, callback)->
  console.log "PARSING!!!"
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
  if data.topic_id == (null) || data.topic_id == ""
    tf = {name:data.topic_name}
  else
    tf = {topic_id:data.topic_id}
  
  # In case you didn't realize where you were, welcome to callback hell.
  # I could probably find out which object we are failing on to figure out what should be dealt with
  
  
  FMs.topic.mergeOrCreate tf
  , {topic_id:data.topic_id, name:data.topic_name}
  , (err, topic_a) ->
    if(err)
      if(err.flight_mes == "d")
        results.duplicates++
      else
        results.rejected++
        callback(err, results)
        return
    topic = topic_a._id
    lics = data.licences.split "\n"
    lic_funk = ()->
      if lics.length > 0
        temp = lics.pop()
        console.log temp
        if(temp == "")
          process.nextTick(lic_funk)
          return
        parts = temp.split "("
        name = parts[0].substring(0,parts[0].length-2)
        parts = parts[1].split ")"
        abr = parts[0]
        refnum = parts[1].substring(1)
        temp = name+" ("+abr+")"
        if(abr == "")
          lf = {name:name}
        else
          lf = {full_name:temp}
        FMs.license.mergeOrCreate {full_name:temp}
        , {full_name:temp,abr:abr,name:name}
        , (err, lic_a) ->
          if(err)
            if(err.flight_mes == "d")
              results.duplicates++
            else
              results.rejected++
              callback(err, results)
              return
          lic.push lic_a._id
          process.nextTick(lic_funk)
          return
      else
        regions = [data.region, data.post_town, data.county]
        parent = (null)
        region_funk = ()->
          if regions.length > 0
            temp = regions.pop()
            FMs.region.findOrCreate {name: temp, level: regions.length,\
            parent: parent}
            , (null)
            , (err, region_a) ->
              if(err)
                if(err.flight_mes == "d")
                  results.duplicates++
                else
                  results.rejected++
                  callback(err, results)
                  return
              if(regions.length == 0)
                rgn = region_a._id
              else
                parent = region_a._id
              region_funk()
          else if(topic != 0)
            temp =
              name: data.company_name
              url: data.url
              topic: topic
              license: lic
              logo_url: data.logo_URL
            FMs.company.mergeOrCreate {name: data.company_name, \
            topic: topic._id}
            , temp
            , (err, cpy_a) ->
              if(err)
                if(err.flight_mes == "d")
                  results.duplicates++
                else
                  results.rejected++
                  callback(err, results)
                  return
              cpy = cpy_a._id
              tp = data.telephone.replace(/\D/g,'')
              fx = data.fax_number.replace(/\D/g,'')
              temp = {\
              address: data.address
              , post_code: data.post_code
              , telephone_number: tp
              , fax_number: fx
              , email: data.email
              , company: cpy
              , region: rgn
              , users: []\
              }
              FMs.address.mergeOrCreate {\
              address: data.address
              , post_code: data.post_code
              , company: cpy
              , region: rgn\
              }
              , temp
              , (err, add_a)->
                if(err)
                  if(err.flight_mes == "d")
                    results.duplicates++
                  else
                    results.rejected++
                    callback(err, results)
                    return
                callback(null,results)
        region_funk()
    lic_funk()

# flight model's CRUD controller.
Route =
  # Lists all Companies
  index: (req, res) ->
    FMs.company.find {}, (err, companies) ->
      res.render "flight/flight-template",
        view : "index"
        user : req.user
        companies : companies
        uploads : if req.user then user2files[req.user.name]  else []
  upload: (req, res)->
    if req.method is 'POST'
      if !req.user || req.user.groups isnt 'admin'
        return res.send(403)
      body = req.body
      if !body?
        return res.send 400, 'Must provide data.'
      form = new formidable.IncomingForm
      form.uploadDir = config.UPLOADS
      scboo = true
      form.on "file", (name, file)->
        scboo = csv_file_handler.prep req, name, file
        return
      form.onPart = (part) ->
        # reject any unexpected file, to prevent exploit.
        if part.filename and part.name isnt 'file'
          console.log 'rejected', part.name, part.filename
          return
        if(scboo) 
          csv_file_handler.handlePart req, part
        form.handlePart(part)
        return
      form.parse req, (err, fields, files) ->
        file = files?.file
        console.log 'uploaded', err, file?.name, file?.path
        return res.send 500, err.message || err if err
        return res.send 200 unless file
        
        if(scboo)
          csv_file_handler.upload req, file, parse_row #for filename, file of files
      if(!req.query || !req.query.page)
        page = 0
      else
        page = req.query.page
      query = FMs.company.find({})
      query.count (err,count)->
        query.skip(20*page).limit(20).populate({path:'topic',select:"name"})\
        .exec (err, companies) ->
          if(err) 
            console.log err
          res.render "flight", {companies : companies, company_count:count}

  company: (req, res)->
    if !req.query.company
      return
  address:  (req,res)->
    
  users:  (req, res)->
  
  orders: (req, res)->
  



module.exports = Route
