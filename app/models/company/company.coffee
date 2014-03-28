#
# Company model

# Company schema
CompanySchema = new Schema(

  active:
    type: Boolean
    default: false

  name:
    type: String
    required: true
    default: false

  website:
    type: String
    required: false
    default: false

  type:
    type: String
    enum: ["event-organiser", "charity"]
    default: false

  topic:
    type: Array
    enum: ["t-shirts", "sweatshirts", "children-ware", "organic-sustainable", "earth-positive", "bespoke", "fashion-forward"]
    required: false

  members:
  	type: Array
  	required: true

)

module.exports = mongoose.model 'CompanySchema', CompanySchema