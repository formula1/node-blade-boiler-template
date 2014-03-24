
async = require "async"
request = require "request"
fs = require "fs"
spawn = require("child_process").spawn
config = require "../config/config"
config.setEnvironment process.env.NODE_ENV

#TRELLO_LIST = process.env.TRELLO_LIST
TRELLO_LIST = "5171a5a18be394b63d005eed"
TRELLO_API_KEY = process.env.TRELLO_API_KEY
TRELLO_TOKEN = process.env.TRELLO_TOKEN

###
JSON parser
to save only cards only from official chapter list
###
get = ()->
  console.log "Getting orders and stock quantaty updates..."
  async.forever ((callback) ->
    official_chapter_list = "https://api.trello.com/1/lists/" + TRELLO_LIST +
      "?cards=open&fields=name&card_fields=desc&key=" + TRELLO_API_KEY +
      "&token=" + TRELLO_TOKEN + ""
    request official_chapter_list, (error, response, body)->
      unless error
        newcontacts = []
        # try to parse recieved list
        try
          chapter_cards = JSON.parse body
          cards = chapter_cards.cards
          # parsing string to JSON object
          for card in cards
            obj = {}
            if card.desc isnt ""
              descriptions = card.desc.split "\n"
              for description in descriptions
                descvalue = description.split "**"
                if descvalue[1]?
                  descvalue[1] = descvalue[1].substr(0, descvalue[1].length - 1)
                  obj[descvalue[1]] = descvalue[2].replace(/^\s+|\s+$/g, "")
                  card.desc = obj
              # if chpter LOCALES not specified it sets to "en-EN"
              if card.desc.LOCALES
                newcontacts.push card
          #try to read chapters.json
          try
            file = fs.readFileSync "./data/chapters.json"
            fs.readFile "./data/chapters.json", (err, oldcontacts)->
              if err
                console.log "./data/chapters.json does not exist"
                throw err
              else
                # check for update
                jsonString = JSON.stringify(newcontacts,null,2)
                oldjson = JSON.parse(oldcontacts)
                oldjsonString = JSON.stringify(oldjson,null,2)
                # console.log("Is new file equals old file?: ", jsonString is oldjsonString);
                if jsonString isnt oldjsonString
                  # update json file
                  fs.writeFile "./data/chapters.json", jsonString, (err) ->
                    unless err
                      console.log "Official chapter list saved"
                    else
                      console.log "cannot writeFile: " + err
                else
                  console.log "nothing to to update"
          catch e
            fs.open "./data/chapters.json", "w", (err, fd) ->
              console.log("OPENING FILE ERROR: ",err)  if err
              unless err
                jsonString = JSON.stringify(newcontacts,null,2)
                fs.writeFile "./data/chapters.json", jsonString, (err)->
                  console.log("WRITING FILE ERROR: ",err)  if err
                  console.log("chapter.json created")  if !err
        catch e
          console.log "Invalid JSON format error: ", e
          throw e
  ), (err) ->
    console.log err  if err

getCards = ()->
  setInterval(get, config.PARSE_INTERVAL)

exports = module.exports = getCards
