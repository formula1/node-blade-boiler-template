#
# User model
# Ideas from http://blog.mongodb.org/post/32866457221/password-authentication-with-mongoose-part-1
# and http://devsmash.com/blog/implementing-max-login-attempts-with-mongoose
#
mongoose = require('mongoose');
Schema = mongoose.Schema;

Topic = new Schema(
  topic_id: 
    type: String
    unique: true
  name:
    type: String
    unique: true
  companies: [Schema.Types.ObjectId]
);

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
  companies: [Schema.Types.ObjectId]
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
    required: false
  children: [Schema.Types.ObjectId]
  addresses: [Schema.Types.ObjectId]
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
  license: [Schema.Types.ObjectId]
  address: [Schema.Types.ObjectId]
  user: [Schema.Types.ObjectId]
);

Address = new Schema(
  address: String
  post_code: String
  telephone_num:
    type: Number
    required:false
  fax_num: 
    type: String
    required: false
  email: 
    type: String
    required: false
  company: Schema.Types.ObjectId
  region: Schema.Types.ObjectId
  user: [Schema.Types.ObjectId]
);

User = new Schema(
  company: 
    type: Schema.Types.ObjectId
    required: true
  address: 
    type: Schema.Types.ObjectId
    required: true
  info:
    type: Schema.Types.ObjectId
	  required: false
)

module.exports =
  topic : mongoose.model "flight_topic" Topic
  license : mongoose.model "flight_license" License
  company : mongoose.model "flight_company" FlightCompany
  address : mongoose.model "flight_address" Address
  region : mongoose.model "flight_region" Region
  user : mongoose.model "flight_user" User