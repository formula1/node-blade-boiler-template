var socketAppHandler;

/*
The SocketAppHandler needs an app with the following
property - name
method - open
method - trigger
method - close
*/

jQuery(function($){

  sAHClass = function(){
    console.log("SAH construct");
    this.apps = {};
    this.socket = new eio.Socket();
    this.openboo = false;
    that = this;
    socket = this.socket;
    this.socket.on('open', function() {
      console.log("open");
      that.openboo = true;
      for(var an in this.apps)
        setTimeout(function(){
          this.apps[an].onOpen(socket);
        }, 1);
    });
    this.socket.on('message', function(data) {
      console.log('message received');
      try {
        var parsed = JSON.parse(data);
        for(var name in this.apps)
          if(name = parsed.app){
            this.apps[name].trigger(parsed.data);
            break;
          }
      }
      catch(e) {
        console.log('error', e.message);
      }
    });
    this.socket.on('close', function() {
      console.log("close");
      that.openboo = false;
      for(var an in this.apps)
        setTimeout(function(){
          this.apps[an].onClose(socket);
        }, 1);
    });
  };
  
  sAHClass.prototype.addApp = function(app){
    //Validation
    if(typeof app != "object") throw new Error("App needs to be an object");
    if(!app.name) throw new Error("App needs a name");
    if(typeof app.name != "string") throw new Error("App.name needs to be a string");
    if(!app.onOpen) throw new Error("App needs onOpen Listener");
    if(typeof app.onOpen != "function") throw new Error("App.onOpen needs to be a function");
    if(!app.onData) throw new Error("App needs onData Listener");
    if(typeof app.onData != "function") throw new Error("App.onData needs to be a function");
    if(!app.onClose) throw new Error("App needs onClose Listener");
    if(typeof app.onClose != "function") throw new Error("App.onClose needs to be a function");
    this.apps[app.name] = app;
    if(this.openboo) this.apps[app.name].onOpen(socket);
  };
  
  sAHClass.prototype.sendMessage = function(app, message){
    if(!this.openboo) throw new Error("can't send messages when not open");
    var name;
    if(typeof app == "string"){
      if(typeof this.apps[app] = "undefined") throw new Error("This App doesn't exist");
      name = app;
    }else if(typeof app == "object"){
      if(!app.name) throw new Error("The App you wish to delete doesn't have a name");
      name = app.name;
    }
    else throw new Error("Can only remove objects and string");
    if(typeof message != "string") throw new Error("Messages can only be strings");
    
    this.socket.send("{\"app\": \""+name+"\", \"data\": \""+message+"\" }");
  }; 
  
  sAHClass.prototype.removeApp = function(app){
    if(typeof app == "string")
      if(typeof this.apps[app] = "undefined") throw new Error("This App doesn't exist");
      else delete(this.apps[app])
    else if(typeof app == "object")
      if(!app.name) throw new Error("The App you wish to delete doesn't have a name");
      else delete(this.apps[app.name])
    else throw new Error("Can only remove objects and string");
  };
  
  socketAppHandler = new sAHClass()
})