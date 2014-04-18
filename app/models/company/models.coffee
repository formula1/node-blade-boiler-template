mongoose = require('mongoose')
Schema = mongoose.Schema
rmv = require "../../utils/m-schema-layer.coffee"

fOCSchema = (settings)->
  ret = rmv(settings)
  console.log("TYPING"+typeof ret)
  ret.statics._findOrCreate = (query,to_save, next)->
    model = this
    this.findOne query, (err, doc) ->
      if err
        err.company_mes = "r"
        process.nextTick ()->
          next(err null)
      if doc
        err = {company_mes:"d"}
        process.nextTick ()->
          next(err, doc)
      else
        if(to_save == null)
          to_save = query
        doc = new model to_save
        doc.save (err, doc) ->
          if err
            err.company_mes = "r"
            process.nextTick ()->
              next(err, null)
          else
            process.nextTick ()->
              next(null, doc)
  ret.statics._mergeOrCreate = (query,to_save, next)->
    model = this
    this.findOne query, (err, doc) ->
      if err
        err.company_mes = "r"
        process.nextTick ()->
      if doc
        console.log "found doc"
        settings = model.schema.paths
        `
        for(var k in model.schema.paths){
          if(!to_save[k]) continue;
          else if(doc[k] == null || doc[k] == "" || doc[k] == [])
            doc[k] = to_save[k]
          else if(settings[k].caster){
            doc[k].addToSet.apply(doc[k], to_save[k]);
          }
          else if(typeof doc[k] == "string" && typeof to_save[k] == "string" && doc[k].valueOf() == to_save[k].valueOf())
            continue
          else if(doc[k].toString().valueOf() == to_save[k].toString().valueOf())
            continue
          else{
            console.log(model.modelName+" cannot merge property: "+k+"(init:"+doc[k]+", tosave:"+to_save[k]+")");
            next("company/models-40: cannot merge property"+k,null);
          }
        }
        `
        doc.save (err, doc)->
          if err
            err.company_mes = "r"
            process.nextTick ()->
              next(err,null)
          err = {company_mes:"d"}
          process.nextTick ()->
            next(err, doc)

      else
        if(to_save == null)
          to_save = query
        doc = new model to_save
        doc.save (err, doc) ->
          if err
            err.company_mes = "r"
            process.nextTick ()->
              next(err, null)
          else
            process.nextTick ()->
              next(err, doc)
  return ret






sTopic = fOCSchema(
  topic_id:
    type: String
    unique: (true)
  name:
    type: String
    unique: (true)
  companies: [{type: Schema.Types.ObjectId, ref:"company"}]
)
sTopic.post 'remove', (doc)->
  if(doc.companies.length > 0)
    for value in doc.companies
      companyCompany.update {_id: value}
      ,{ $pull: { license: doc._id } }
      ,(err)->
        if(err)
          console.log("License could not update: "+err)

sLicense = fOCSchema(
  abr:
    type: String
    unique: true
  name:
    type: String
    unique: true
  full_name:
    type: String
    unique: true
  companies: [{type: Schema.Types.ObjectId, ref:"company"}]
)
sLicense.post 'remove', (doc)->
  if(doc.companies.length > 0)
    for value in doc.companies
      companyCompany.update {_id: value}
      ,{ $pull: { license: doc._id } }
      ,(err)->
        if(err)
          console.log("License could not update: "+err)


sRegion = fOCSchema(
  name:
    type: String
    required: true
  level:
    type: Number
    required: true
  parent:
    type: Schema.Types.ObjectId
    ref: "company_region"
    required: false
  children: [{type: Schema.Types.ObjectId, ref:"company_region"}]
  addresses: [{type: Schema.Types.ObjectId, ref:"company_address"}]
)
sRegion.post 'save', (doc)->
  if(doc.parent != null)
    Region.update { _id: doc.parent }
    ,{ $addToSet: { children: doc._id } }
    ,(err)->
      if(err)
        console.log("Region Parent could not update: "+err)

sRegion.post 'remove', (doc)->
  if(doc.parent != null)
    Region.update { _id: doc.parent }
    , { $pull: { children: doc._id } }
    ,(err)->
      if(err)
        console.log('Region Parent could not update'+err)
  if(doc.children.length > 0)
    for value in doc.children
      Region.update {_id: value}
      , { $set: { parent: doc.parent } }
      , (err)->
        if(err)
          console.log('Child could not update'+err)
  if(doc.addresses.length > 0)
    if(doc.parent != null)
      for value in doc.addresses
        Region.update {_id: value}
        , { $set: { parent: doc.parent } }
        , (err)->
          if(err)
            console.log('Address could not update'+err)
    else
      console.log("Your company Database has a huge problem")


scompanyCompany = fOCSchema(
  name:
    type: String
    unique: true
    required: true
  url:
    type: String
    required: false
  logo_url:
    type: String
    required: false
  topic: {type:Schema.Types.ObjectId, ref: "company_topic", required:false}
  license: [{type: Schema.Types.ObjectId, ref:"company_license"}]
  addresses: [{type: Schema.Types.ObjectId, ref:"company_address"}]
  users: [{type: Schema.Types.ObjectId, ref: "company_id"}]
)
scompanyCompany.method "_createHook", (req, res, next)->
  the_company = this
  User.findOne {user:req.user._id}, (err, company_id)->
    if(err)
      console.log(err)
      next(err)
    else if(!company_id)
      console.log("could not find this user")
      next("could not find this user")
    else
      company_id.company = the_company._id
      company_id.role = "admin"
      company_id.save (err)->
        if(err)
          next(err)
        next()

scompanyCompany.post 'save', (doc)->
  console.log(doc.topic)
  if(doc.topic)
    Topic.update { _id: doc.topic }
    ,{ $addToSet: { companies: doc._id } }
    ,(err)->
      if(err)
        console.log("Topic could not update: "+err)
  if(doc.license.length > 0)
    for value in doc.license
      License.update {_id: value}
      ,{ $addToSet: { companies: doc._id } }
      ,(err)->
        if(err)
          console.log("License could not update: "+err)

scompanyCompany.post 'remove', (doc)->
  Topic.update { _id: doc.topic }
  ,{ $pull: { companies: doc._id } }
  ,(err)->
    if(err)
      console.log("Topic could not update: "+err)
  if(doc.license.length > 0)
    for value in doc.license
      License.update {_id: value}
      ,{ $pull: { companies: doc._id } }
      ,(err)->
        if(err)
          console.log("License could not update: "+err)

sAddress = fOCSchema(
  address: 
    type: String
    required: true
  post_code: 
    type: String
    required: true
  telephone_number:
    type: String
    required:false
  fax_number:
    type: String
    required: false
  email:
    type: String
    required: false
  company: {type: Schema.Types.ObjectId, ref:"company", required: true}
  region: {type: Schema.Types.ObjectId, ref:"company_region", required: true}
  users: [{type: Schema.Types.ObjectId, ref:"company_id"}]
  docSlug: "address"
)
sAddress.post 'save', (doc)->
  companyCompany.update { _id: doc.company }
  ,{ $addToSet: { addresses: doc._id } }
  ,(err)->
    if(err)
      console.log("Company could not update: "+err)
  Region.update { _id: doc.region }
  ,{ $addToSet: { addresses: doc._id } }
  ,(err)->
    if(err)
      console.log("Region could not update: "+err)
sAddress.post 'remove', (doc)->
  companyCompany.update { _id: doc.company }
  ,{ $pull: { addresses: doc._id } }
  ,(err)->
    if(err)
      console.log("Company could not update: "+err)
  Region.update { _id: doc.region }
  ,{ $pull: { addresses: doc._id } }
  ,(err)->
    if(err)
      console.log("Region could not update: "+err)
  if(doc.users.length > 0)
    for value in doc.users
      sUser.update {_id: value}
      ,{ $set: { company: null, address: null, permission:"guest"} }
      ,(err)->
        if(err)
          console.log("Company Member could not update: "+err)

sUser = fOCSchema(
  permission:
    type: String
    enum: ["admin", "manager", "employee", "guest"]
    default: "guest"
  company:
    type: Schema.Types.ObjectId
    ref: "company"
    required: false
  address:
    type: Schema.Types.ObjectId
    ref: "company_address"
    required: false
  user:
    type: Schema.Types.ObjectId
    ref: "User"
    required: true
    unique: true
  name:
    type: String
  activated:
    type:Boolean
    default:(false)
  userAssociated: (true)
)

sUser.static "activate", (req,res,next)->
  user = req.user
  company_id = this
  company_id.findOne {user:user._id}, (err,doc)->
    if(err)
      console.log(err)
    else if(doc && doc.activated)
      next("You have already Activated")
    else if(doc && !doc.activated)
      doc.activated = (true)
      doc.name = user.name
      doc.save (err)->
        if(err)
          next(err)
        else
          next()
    else
      doc = new company_id({user:user._id,name:user.name,activated:true})
      doc.save (err)->
        if(err)
          next(err)
        else
          next()
        
      

sUser.pre "save", (next)->
  if(!this.user)
    next("Need a User")
  SiteUser = mongoose.model("User")
  SiteUser.findOne {_id:this.user}, (err,user)->
    if(err)
      next(err)
    if(!user)
      next("This user does not Exist")
    else
      this.name = user.name+" "+user.surname
      next()



sUser.post 'save', (doc)->
  Address.update { _id: doc.address }
  ,{ $addToSet: { users: doc._id } }
  ,(err)->
    if(err)
      console.log("Address could not update: "+err)
  companyCompany.update { _id: doc.company }
  ,{ $addToSet: { users: doc._id } }
  ,(err)->
    if(err)
      console.log("Company could not update: "+err)
sUser.post 'remove', (doc)->
  companyCompany.update { _id: doc.company }
  ,{ $pull: { users: doc._id } }
  ,(err)->
    if(err)
      console.log("Company could not update: "+err)
  Address.update { _id: doc.address }
  ,{ $pull: { users: doc._id } }
  ,(err)->
    if(err)
      console.log("Address could not update: "+err)

Topic = mongoose.model "company_topic", sTopic
License = mongoose.model "company_license", sLicense
companyCompany = mongoose.model "company", scompanyCompany
Address = mongoose.model "company_address", sAddress
Region = mongoose.model "company_region", sRegion
User = mongoose.model "company_id", sUser
module.exports =
  topic : Topic
  license : License
  company : companyCompany
  address : Address
  region : Region
  user : User