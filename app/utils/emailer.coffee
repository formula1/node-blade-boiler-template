# /src/utils/emailer.coffee

config = require "../config/config"
emailer = require("nodemailer")
fs      = require("fs")
_       = require("underscore")

class Emailer

  options: {
    #template:
    #to:
      #name:
      #surname:
      #email:
  }
  data: {
    #pass:
    #link:
  }
  # Define attachments here
  attachments: [
    fileName: "logo.png"
    filePath: "./public/images/email/logo.png"
    cid: "logo@continentalclothing.com"
  ]

  constructor: (@options, @data)->

  send: (callback)->
    # console.log @data
    console.log "emailing"
    html = "follow this link: <a href=#{@data.link}>#{@data.link}</a><br> to reset your password<img class='cid:logo@continentalclothing.com'></img>" if @options.template is 'reset'
    html = "follow this link: <a href=#{@data.link}>#{@data.link}</a><br> to verify your email anddress and create account<br><img class='cid:logo@continentalclothing.com'></img>" if @options.template is "activation"

    #FIXME doesnt work getHtml() cannot put @data to template, unexpected token '=' at (<h3><%= pass %></h3>)
    #html = @getHtml(@options.template, @data)

    attachments = @getAttachments(html)
    messageData =
      #to: "'#{@options.to.name} #{@options.to.surname}' <#{@options.to.email}>"
      to: "<#{@options.to.email}>"
      from: "noreply@localhost"
      subject: @options.subject
      html: html
      generateTextFromHTML: true
      attachments: attachments
    transport = @getTransport()
    transport.sendMail messageData, callback

  getTransport: ()->
    if(process.env.SMTP_SERVICE)
      return emailer.createTransport "SMTP",
        service: process.env.SMTP_SERVICE
        auth:
          user: config.SMTP.user,
          pass: config.SMTP.pass
    else
      console.log("defaulting")
      return emailer.createTransport("direct", {debug:true})

  getHtml: (templateName, data)->
    templatePath = "./views/emails/#{templateName}.html"
    templateContent = fs.readFileSync(templatePath, encoding= "utf8")
    _.template templateContent, data, {interpolate: /\{\{(.+?)\}\}/g}

  getAttachments: (html)->
    attachments = []
    for attachment in @attachments
      attachments.push(attachment) if html.search("cid:#{attachment.cid}") > -1
    attachments

exports = module.exports = Emailer
