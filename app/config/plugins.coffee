### Routes
# We are setting up these routes:
#
# GET, POST, PUT, DELETE methods are going to the same controller methods - we dont care.
# We are using method names to determine controller actions for clearness.
###
fs = require 'fs'
hooks = {}

getPlugins = ()->
  plugins = []
  fs.readdirSync(process.cwd() + "/app/plugins").forEach (file) ->
      plugins.push require(process.cwd() + "/app/plugins/"+file)
  return plugins

iterate_plugins = (command, counter, err_arr, req, res, cb)->
  if(counter == hooks[command].length)
    cb(err_arr,req,res)
  else
    hooks[command][counter] req, res, (err, req, res)->
      if(err)
        err_arr.push(err)
      counter++
      process.nextTick ()->
        iterate_plugins(command,counter,err_arr,req,res,cb)
  
module.exports = 
  initiateFilter: (command)->
    if(!hooks[command])
      plugins = getPlugins()
      `
      for(var i=0;i<plugins.length;i++)
        if(!plugins[i][command]){
          plugins.splice(i,1);
          i--;
        }else
          plugins[i]=plugins[i][command]
      plugins.sort(
        function(a,b){
          if(!a.weight)
            a.weight = 1;
          if(!b.weight)
            b.weight = 1;
          return a.weight-b.weight
        }
      );
      `
      hooks[command] = plugins
  emit: (command, req, res, next)->
    if(!hooks[command])
      next((undefined),req, res)
    else
      iterate_plugins(command,0,[],req,res,next)
