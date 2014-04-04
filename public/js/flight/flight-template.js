/*
This is flight template javascript
-implements ajax for the main menu
-implments hiding of all other sidebar items when one is selected
*/

$(function($){
  $(".flight_sidebar_item>h3").click(function(e){
    e.preventDefualt();
    var opener = $(this).parent();
    $(".flight_sidebar_item").each(function(item){
      if(item == opener)
        $(item).find(".flight_sidebar_item_content").stop().show("slow");
      else
        $(item).find(".flight_sidebar_item_content").stop().hide("slow");
    });
  });
  
  $(".flight_menu a").click(function(e){
    e.preventDefault();
    var elem = $(this);
    $.ajax("/view/"+elem.attr("href")).done(function(data){
      $(".flight_main").html(data);
    });
  });
})