module.exports =
  I18N =
    detectLngQS: "lang"
    resGetPath: "locales/__lng__/__ns__.json"
    ns: { namespaces: ['ns.common', 'ns.layout', 'ns.forms', 'ns.msg'], defaultNs: 'ns.common'}
    ignoreRoutes: ["images/", "public/", "css/"]
    extension:".json"