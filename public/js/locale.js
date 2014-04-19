jQuery(function($) {
    $("#remember_me").click(function(e) {
      if ($("#remember_me").val() == "off"){
        $("#password").attr("disabled", true)
        $(".btn-continue").removeClass("hidden")
        $(".btn-login").addClass("hidden")
        $("#email").focus()
        $("#form_login_user").attr("action", "/authenticate/local/setup")
        $("#remember_me").val("on")
      }else{
        $("#password").attr("disabled", false)
        $(".btn-continue").addClass("hidden")
        $(".btn-login").removeClass("hidden")
        $("#form_login_user").attr("action", "/authenticate/local")
        $("#remember_me").val("off")
      }
      console.log($("#form_login_user").attr("action"));
    })
    
    $('#save').click(function(cb) {
        $('#user_edit_profile').validate({
          rules: {
              surname:{
                required: false
                ,minlength: 3
              },name:{
                required: false
                ,minlength: 3
              },password_old: {
                required: function(element) {
                  return $("#password_new").val().length >= 6
                },minlength: 6
              },password_new: {
                required: function(element) {
                  return $("#password_old").val().length >= 6
                },minlength: 6
              },
              password_confirm: {
                equalTo: "#password_new",
                required: function(element) {
                    return $("#password_old").val().length >= 6
                  }
              },

          },
          messages: {
              name: {
                required: $('#saveerr').text()
                ,minlength: $('#namelength').text()
              },
              surname: {
                required: $('#saveerr').text()
                ,minlength: $('#surnamelength').text()
              },
              password_old: {
                minlength: $('#passlength').text()
                ,required: $('#oldpassreq').text()
              },
              password_new: {
                minlength: $('#passlength').text()
                ,required: $('#newpassreq').text()
              },
              password_confirm: {
                minlength: $('#passlength').text()
                ,equalTo: $('#passequal').text()
                ,required: $('#confirmpassreq').text()
              }
          }
        })
    })  

    $('#login').click(function(cb) {
        $('#form_login_user').validate({
            rules:{
                email:{
                  email: true
                  ,required: true
                },password:{ 
                  required: true
                  ,minlength: 6 
                }
            },
            messages:{
                email:{
                    email: $('#emailvalid').text()
                    ,required: $('#emailreq').text()
                },password:{
                    required: $('#passreq').text()
                    ,minlength: $('#passlength').text()
                }
            }
      })
    }) 
    $('#continue').click(function(cb) {
      $('#form_login_user').validate({
          rules:{
              email:{
                email: true
                ,required: true
              },password:{
                required: false
              }
          },messages:{
              email:{
                email: $('#emailvalid').text()
                ,required:  $('#emailreq').text()
              },password:{
                requried: ''
              }
          }
      })
    })

    $('#reset').click(function(cb) {
        $('#form_reset_password').validate({
          rules: {
              password_new: {
                  required: true
                  ,minlength: 6
              },
              password_confirm: {
                  required: true
                  ,equalTo: "#password_new"
              }
          },
          messages: {
              password_new: {
                  required: $('#newpassreq').text()
                  ,minlength: $('#passlength').text()
              },
              password_confirm: {
                  required: $('#confirmpassreq').text()
                  ,minlength: $('#passlength').text()
                  ,equalTo:  $('#passequal').text()
              }
          }
        })
    })  
});
