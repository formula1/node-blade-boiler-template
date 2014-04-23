fs = require "fs"

iana = fs.readFileSync(__dirname+"/IANA.txt", {encoding:"utf-8"})
iana = iana.split "%%"
console.log("LENGTH"+iana.length)
prep = []
for single in iana
  single = single.split "\n"
  if(single[1].indexOf("Type: region") != 0)
    continue
  prep.push {pretty:single[3].substring(13), abbr:single[2].substring(8)}

prep.sort( (a,b)->
  return a.pretty.localeCompare(b.pretty)
)
iana = prep
prep = undefined
console.log("LENGTH"+iana.length)

yesTillNo = (search, index, prev, next, found, cb)->
  if(prev == -1 && next == -1)
    return cb(found)
  if(prev != -1 && prev+next < 10 && iana[index-prev].pretty.toLowerCase().indexOf(search) == 0)
    found.unshift iana[index-prev]
    prev += 1
  else
    prev = -1
  if(next != -1 && prev+next < 10 && iana[index+next].pretty.toLowerCase().indexOf(search) == 0)
    found.push iana[index+next]
    next += 1
  else
    next = -1
  process.nextTick ()->
    yesTillNo search, index, prev, next, found, cb

binarysearch = (search, max, min, mid, cb)->
  if(iana[mid].pretty.toLowerCase().indexOf(search) == 0)
    process.nextTick ()->
      yesTillNo(search, mid, 1, 1, [iana[mid]], cb)
    return
  console.log(iana[mid].pretty.toLowerCase()+" && "+search)
  if(mid == min  || mid == max)
    return cb([])
  n = iana[mid].pretty.toLowerCase().localeCompare(search)
  if(n > 0)
    min = mid
    mid = Math.floor((max+min)/2)
    process.nextTick ()->
      binarysearch search, max, min, mid, cb
    return
  else
    max = mid
    mid = Math.floor((max+min)/2)
    process.nextTick ()->
      binarysearch search, max, min, mid, cb
    return
  
module.exports =
  autocomplete: (req, res, next)->
    if(!req.query.pretty)
      next()
    console.log(iana.length)
    console.log(iana.length/2)
    binarysearch req.query.pretty.toLowerCase(), 0, iana.length-1, Math.floor(iana.length/2), (found)->
      console.log(found)
      res.json(found)