#= require vendor/jquery/jquery.min.js
#= require vendor/jquery/jquery.validate.min.js
#= require vendor/spark.min.js
#= require vendor/engine.io.js
#= require vendor/i18next/i18next-1.7.2.min.js
#= require vendor/purl.js
#= require vendor/jquery/jquery.cookie.min.js
#= require vendor/jquery/jquery.validate.min.js
#= require persona.js
#= require vendor/bootstrap/bootstrap.min.js
#= require vendor/bootstrap/bootstrap-tab.js
#= require locale.js

setTimeout(
  -> $('.flashMessage').fadeOut(1000, -> $(this).remove())
  3000
)
$(document).ready ->
  s = skrollr.init()
  $(document).foundation reveal:
    animation: "fadeAndPop"
    animation_speed: 1000
    close_on_background_click: true
    close_on_esc: true
    dismiss_modal_class: "close-reveal-modal"
    bg_class: "reveal-modal-bg"
    open: ->
      console.log "fired from settings"
      return

    opened: ->

    close: ->

    closed: ->

      bg: $(".reveal-modal-bg")
      css:
        open:
          opacity: 0
          visibility: "visible"
          display: "block"

        close:
          opacity: 1
          visibility: "hidden"
          display: "none"

  return

