mongoose = require('mongoose')
Schema = mongoose.Schema

Topic = new Schema(
  topic_id:
    type: String
    unique: true
  name:
    type: String
    unique: true
  companies: [{type: Schema.Types.ObjectId, ref:"flight_company"}]
)

License = new Schema(
  abr:
    type: String
    unique: true
  name:
    type: String
    unique: true
  full_name:
    type: String
    unique: true
  companies: [{type: Schema.Types.ObjectId, ref:"flight_company"}]
)

Region = new Schema(
  name:
    type: String
    required: true
  level:
    type: Number
    required: true
  parent:
    type: Schema.Types.ObjectId
    ref: "flight_region"
    required: false
  children: [{type: Schema.Types.ObjectId, ref:"flight_region"}]
  addresses: [{type: Schema.Types.ObjectId, ref:"flight_address"}]
)

FlightCompany = new Schema(
  name:
    type: String
    unique: true
  url:
    type: String
    required: false
  logo_url:
    type: String
    required: false
  topic: Schema.Types.ObjectId
  license: [{type: Schema.Types.ObjectId, ref:"flight_license"}]
  addresses: [{type: Schema.Types.ObjectId, ref:"flight_address"}]
  user: [{type: Schema.Types.ObjectId, ref: "flight_user"}]
)

Address = new Schema(
  address: String
  post_code: String
  telephone_number:
    type: Number
    required:false
  fax_number:
    type: String
    required: false
  email:
    type: String
    required: false
  company: {type: Schema.Types.ObjectId, ref:"flight_company"}
  region: {type: Schema.Types.ObjectId, ref:"flight_region"}
  user: [{type: Schema.Types.ObjectId, ref:"flight_user"}]
)

User = new Schema(
  company:
    type: Schema.Types.ObjectId
    ref: "flight_company"
    required: true
  address:
    type: Schema.Types.ObjectId
    ref: "flight_region"
    required: true
  info:
    type: Schema.Types.ObjectId
    required: false
)

module.exports =
  topic : mongoose.model "flight_topic", Topic
  license : mongoose.model "flight_license", License
  company : mongoose.model "flight_company", FlightCompany
  address : mongoose.model "flight_address", Address
  region : mongoose.model "flight_region", Region
  user : mongoose.model "flight_user", User