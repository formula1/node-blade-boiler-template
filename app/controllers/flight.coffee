FMs = require "../models/flight/models"
formidable = require "formidable"
config = require "../config/config"
csv = require "fast-csv"
engine = require '../config/engine'



engine.on 'join:/flight/index', (socket) ->
  return unless socket.user?.groups is 'admin'
  user2socket[socket.user.name] = socket
  user2socket[socket.user.name].on "close" ()->
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
        objects_per_row
        added: 0
  handlePart(req, part)->
    if !user2files[req.user.name][part.filename]
      return
    user2files[req.user.name][part.filename].max += part.split("\n").length
  upload(req, file, row_handler)->
    stream = fs.createReadStream(file.path);
    error = false;

    csv().fromStream stream {headers:true}.on("record", (data)->
      console.log(data):
      if(error) return;
      row_handler data, (err, results)->
        if(err)
          if user2socket[req.user.name]
            user2socket[req.user.name].send JSON.stringify(err)
          error = err
          return;
        user2files[req.user.name][file.name].rejected += results.rejected
        user2files[req.user.name][file.name].duplicant += results.duplicant
        user2files[req.user.name][file.name].added += results.added
        user2files[req.user.name][file.name].object_per_row = results.objects_per_row
        user2files[req.user.name][file.name].total++
        if user2socket[req.user.name]
          user2socket[req.user.name].send JSON.stringify(user2files[req.user.name][file.name])
      
    ).on("end", ()->
      console.log JSON.stringify(user2files[req.user.name][file.name]);
      fs.unlink file.path, (err) ->
        console.log 'deleted', file.path
        cb err
    );

parse_row = (data, callback)->
  results = 
    rejected:0
    duplicant:0
    addes:0
    objects_per_row = 8
    
  topic = 0
  lic = []
  rgn = 0
  cpy = 0
  addrss = 0
  usr = 0
  error = false # I should check if topic even exsists before I start
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
      topic.save (err) ->
        if err
          results.rejected++
          error = err
          callback(err)
          return
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
            lic.push lic_a
            lic_funk()
          else
            parts = temp.split "("
            parts[0] = parts[0].substring(0,parts[0].length-2)
            parts[1] = parts[1].substring(0,parts[1].length-2)
            lic.push new FMs.license {full_name:temp,abr:parts[1],name:parts[0]}
            lic.save (err) ->
              if err
                results.rejected++
                error = err
              lic_funk()
      else
        regions = [data.region, data.post_town, data.county]
        parent = null
        
        region_funk = ()->
          if regions.length > 0
            temp = regions.pop()
            FMs.region.findOne {name: temp, level: regions.length, parent: parent}, (err, region_a) ->
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
                saved = new FMs.region {name: temp, level: regions.length, parent:parent}
                if(parent != null)
                  parent.children.push saved._id #this doesn't work as the id isn't set yet
                  saved.parent = parent._id
                  parent.save (err) ->
                    if err
                      results.rejected++
                      error = err
                    saved.save (err) ->
                      if(err)
                        results.rejected++
                        error = err
                      if(regions.length == 0) rgn = saved
                      region_funk()
          else if(topic != 0)
            FMs.company.findOne {name: data.company_name, topic: topic._id}, (err, cpy_a) ->
              if err
                results.rejected++
                error = err
                callback err
                return;
              if cpy_a
                results.duplicates++
                if(cpy_a.topic == null)
                  cpy_a.topic = topic._id
                if(lic.length > 0)
                  
                cpy = cpy_a
              else
                lic_ids = []
                lic_ids.push lic_i._id for lic_i in lic
                cpy = new FMs.company {name: data.company_name, topic: topic._id, license: lic_ids}
                
                  

  FMs.Company.findOne {name:data.company_name}, (err, cpny_a) ->
    if err
      results.rejected++
    if cpny_a
      results.duplicates++
      cpny = cpny_a
    else
      cpny = new FMs.company data
      user.save (err) ->
        if err then results.rejected++
        else results.added++

        complete err
    

# flight model's CRUD controller.
Route =
  # Lists all Companies
  index: (req, res) ->
    # FIXME set permissions to see this - only admins
    if req.method is 'POST'
      if !req.user || req.user.groups isnt 'admin'
        return res.send(403);
      body = req.body
      if !body?
        return res.send 400, 'Must provide data.'
      action = body.action || req.query.action
      return res.send 400, 'Must provide valid action type.' unless action
      if action is "upload"
        form = new formidable.IncomingForm
        form.uploadDir = config.UPLOADS
        form.on("filebegin", (name, file)->
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
        FMs.company.find {}, (err, companies) ->
          res.render "flight/company",
            companies : companies
      else
        return res.send 400, 'Must provide valid action type.' unless action
    else 
      FMs.company.find {}, (err, companies) ->
          res.render "flight/company",
            companies : companies



module.exports = Route
