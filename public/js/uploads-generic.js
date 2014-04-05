jQuery(function($){

var uploads_csv = {
  name:"CSV-uploader",
  onOpen:function(socket){
    $("p.uploader.alert").removeClass("alert-danger").addClass("alert-success").text("Connected");
    $("p.uploader.alert").attr("title", "You will now see live updates of the CSVs you upload")
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
    $("p.uploader.alert").attr("title", "You will not see live updates of the CSVs you upload")
  }
};

if(typeof socketAppHandler == "object") socketAppHandler.addApp(uploads_csv);

$('#flight_csv_upload_form :file').change(function(file){
  var type = file.type;
  if(type != "csv")
    return false;
    
    //Your validation
});

$("#flight_csv_upload_form").submit(function(e){
  e.preventDefault();
  var that = $(this);
  var formData = new FormData($('#flight_csv_upload_form')[0]);
  
  $.ajax({
      url: that.attr("action"),  //Server script to process data
      type: 'POST',
      xhr: function() {  // Custom XMLHttpRequest
          var myXhr = $.ajaxSettings.xhr();
          if(myXhr.upload){ // Check if upload property exists
              myXhr.upload.addEventListener('progress',function(e){
                if(e.lengthComputable){
                    $('progress').attr({value:e.loaded,max:e.total});
                    var progressbar = $('div.uploads-container .uploads_progress>.progress-bar');
                    progressbar.attr("style", "width:"+Math.round(100*e.loaded/e.total)+"%");
                    progressbar.html(e.loaded+" / "+ e.total);
                }
              }, false); // For handling the progress of the upload
          }
          return myXhr;
      },
      //Ajax events
      beforeSend: function(e){
        var progress = $('div.uploads-container .uploads_progress');
        if(progress.size() == 0){
          progess = $('<div class="uploads_progess progress progress-striped active">');
          progress.append('<div class="progress-bar" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100">0%</div>');
          $("div.uploads-container").append(progress);
        }else{
          progress.removeClass("progress-bar-success").removeClass("progress-bar-danger").stop();
          progress.show("fast");
        }
      },
      success: function(data){
        var progress = $('div.uploads-container .uploads_progress');
        progress.addClass("progress-bar-success");
        progress.children(".progress-bar").html("Success!");
        progress.delay(2000).hide("slow").remove();
        $(".flight_main").replaceWith(data);
      },
      error: function(e){
        var progress = $('div.uploads-container .uploads_progress');
        progress.addClass("progress-bar-danger");
        progress.children(".progress-bar").html("We have an Error");
        progress.delay(2000).hide("slow").remove();
        console.log(e);
      },
      // Form data
      data: formData,
      //Options to tell jQuery not to process data or worry about content-type.
      cache: false,
      contentType: false,
      processData: false
  });
  return false;
})

});