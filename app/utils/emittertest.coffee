emit = require("events").EventEmitter

ret = new emit()
lastdate = Date.now()
console.log("TYPING:"+typeof ret)
ret.run = ()->
  newdate = Date.now()
  if newdate - lastdate > 5000
    ret.emit "emit"
    lastdate = newdate
  process.nextTick(ret.run)
  return
  
module.exports = ret;