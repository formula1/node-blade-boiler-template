#= require vendor/jquery/jquery.min.js
#= require vendor/jquery/jquery.validate.min.js
#= require vendor/spark.min.js
#= require vendor/engine.io.js
#= require vendor/purl.js
#= require vendor/jquery/jquery.validate.min.js
#= require persona.js
#= require vendor/bootstrap/bootstrap.min.js
#= require vendor/bootstrap/bootstrap-tab.js
#= require locale.js

setTimeout(
  -> $('.flashMessage').fadeOut(1000, -> $(this).remove())
  3000
)

