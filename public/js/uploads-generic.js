jQuery(function($){

var uploads_csv = {
  name:"CSV-uploader",
  onOpen:function(socket){
    $("p.uploader.alert").removeClass("alert-danger").addClass("alert-success").text("Connected");
  },
  onData:function(data){
    var elem = $("[data-uploadid='"+data.name+"']");
    if(elem.size() == 0){
      elem = $("<div class='upload_item' data-uploadid='"+data.name+"'></div>");
      $(".uploads_container").append(elem);
    }
    
    elem.clear();
    elem.append(data.total+"/"+data.max+" rows finished"+"<br/>");
    elem.append(data.objects_per_row+" objects per row"+"<br/>");
    elem.append(data.duplicates+" objects avoided duplication"+"<br/>");
    elem.append(data.rejected+" objects rejected"+"<br/>");
  },
  onClose:function(socket){
    $("p.uploader.alert").removeClass("alert-success").addClass("alert-danger").text("Not Connected");
  }
};

socketAppHandler.addApp(uploads_csv);

});