var ac_enroute = {}

jQuery(function($){
  $("input.autocomplete['type'='text']")
  .change(function(e){
    that = $(this);
    form = that.parentsUntil("form");
    url = form.attr("action");
    enroute = that.attr("data-autocom");
    if(enroute && enroute != "")
      for(poss in ac_enroute[enroute])
        if(ac_enroute[enroute][poss].string.startsWith(that.value))
          input


      ac_enroute[enroute]
    if(ac_enroute
  });

});