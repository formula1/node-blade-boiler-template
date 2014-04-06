$(function($) {

  $('.user-login-register-form').click(function (e) {
      e.preventDefault(); $(this).tab('show');
  });
  $('.user-login-register-form a:first').tab('show');

});
