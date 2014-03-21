module.exports = (env) ->

  # ##Dependencies
  # * from node.js
  util = require 'util'
  fs = require 'fs'
  path = require 'path'

  # * pimatic imports.
  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  express = env.require "express" 
  coffee = env.require 'coffee-script'
  S = env.require 'string'
  M = env.matcher

  global.i18n = env.require('i18n')
  global.__ = i18n.__
  _ = env.require 'lodash'

  # * own
  socketIo = require 'socket.io'
  global.nap = require 'nap'

  # ##The MobileFrontend
  class MobileFrontend extends env.plugins.Plugin
    pluginDependencies: ['rest-api']
    additionalAssetFiles:
      'js': []
      'css': []
      'html': []
    assetsPacked: no

    # ###init the frontend:
    init: (@app, @framework, @jsonConfig) ->
      conf = convict require("./mobile-frontend-config-schema")

      # do some legacy support
      for item in @jsonConfig.items
        if item.type is 'actuator' or item.type is 'sensor'
          item.type = 'device'
        switch item.type
          when "device"
            unless item.itemId
              item.itemId = @genItemId(item.type, item.id, @jsonConfig.items)
            if item.id and (not item.deviceId?)
              item.deviceId = item.id
            delete item.id
          when "header", 'button'
            unless item.itemId
              item.itemId = @genItemId(item.type, item.text, @jsonConfig.items)
            delete item.id
            if item.type is 'button' and not item.buttonId?
              item.buttonId = item.itemId.replace('button-', '')

      conf.load @jsonConfig
      conf.validate()
      @config = conf.get ""
        
      # * Delivers json-Data in the form of:

      # 
      #     {
      #       "items": [
      #         { "id": "light",
      #           "name": "Schreibtischlampe",
      #           "state": null },
      #           ...
      #       ], "rules": [
      #         { "id": "printerOff",
      #           "condition": "its 6pm",
      #           "action": "turn the printer off" },
      #           ...
      #       ]
      #     }
      # 
      app.get '/data.json', (req, res) =>
        @getInitalClientData().then( (data) =>
          res.send data
        ).done()
    
      ###
      Handle get request for add a device to the item list.
      ###
      app.get('/add-device/:deviceId', (req, res) =>
        deviceId = req.params.deviceId
        # If no id is given then send an error.
        if not deviceId?
          return res.send(200, {success: false, message: 'no id given'})
        # If the item does not exists then send an error
        found = _(@config.items).find({type: 'device', deviceId: deviceId})
        if found?
          res.send(200, {success: false, message: __('Device was already added.')})
          return
        # else add the item to the item list and send success
        @addNewItem({
            itemId: @genItemId('device', deviceId)
            type: 'device'
            deviceId: deviceId
        })
        res.send(200, {success: true, message: __("Added %s to the list.", deviceId)})
      )
    
      ###
      Handle get request for add a header to the item list.
      ###
      app.get('/add-header/:text', (req, res) =>
        text = req.params.text
        # If no text is given then send an error.
        if text is ""
          return res.send(200, {success: false, message: 'no text given'})
        # else add the item to the item list and send success
        @addNewItem({
          itemId: @genItemId('header', text)
          type: 'header'
          text: text
        })
        res.send(200, {success: true})
      )

      ###
      Handle get request for add a button to the item list.
      ###
      app.get('/add-button/:text', (req, res) =>
        text = req.params.text
        # If no text is given then send an error.
        if text is ""
          return res.send(200, {success: false, message: 'no text given'})
        # else add the item to the item list and send success
        itemId = @genItemId('button', text)
        @addNewItem({
          itemId: itemId
          buttonId: itemId.replace('button-', '')
          type: 'button'
          text: text
        })
        res.send(200, {success: true})
      )

      ###
      Handle post request for removing an item.
      ###
      app.post('/remove-item', (req, res) =>
        itemId = req.body.itemId
        unless itemId?
          return res.send(200, {success: false, message: 'no itemId given'})

        item = _(@jsonConfig.items).first({itemId: itemId})
        unless item?
          return res.send(200, {success: false, message: 'could not find item'})

        _(@jsonConfig.items).remove({itemId: itemId})
        @config.items = @jsonConfig.items
        @framework.saveConfig()

        @emit('item-remove', item)
        res.send(200, {success: true})
      )

      ###
      Handle post request for updating the item list ordering.
      ###
      #TODO: probably fix!
      app.post('/update-item-order', (req, res) =>
        order = req.body.order
        # If no order is given then send and error.
        unless order?
          return res.send(200, {success: false, message: 'no order given'})

        # sort items by given order
        @jsonConfig.items = _(@jsonConfig.items).sortBy( (item) => 
          index = order.indexOf item.itemId
          # push it to the end if not found
          return if index is -1 then 99999 else index 
        ).value()
        @config.items = @jsonConfig.items
        @framework.saveConfig()
        @emit 'item-order', order
        res.send 200, {success: true}
      )

      ###
      Handle post request for updating the rule list sorting.
      ###
      app.post('/update-rule-order', (req, res) =>
        order = req.body.order
        unless order?
          res.send 200, {success: false, message: 'no order given'}
          return
        @config.rules = @jsonConfig.rules = _(order).map( (id)=> {id: id}).value()
        @framework.saveConfig()
        @emit 'rule-order', order
        res.send 200, {success: true}
      )
    
      ###
      Handle get request for clearing the log
      ###
      app.get('/clear-log', (req, res) =>
        env.logger.transports.memory.clearLog()
        res.send(200, {success: true})
      )

      ###
      Handle get request for button press
      ###
      app.get('/button-pressed/:buttonId', (req, res) =>
        buttonId = req.params.buttonId
        item = _(@config.items).first({type: 'button', buttonId: buttonId})
        unless item?
          return res.send(200, {success: false, message: 'could not find the button'})
        @emit "button pressed", item
        res.send(200, {success: true})
      )

      app.get '/enabledEditing/:state', (req, res) =>
        state = req.params.state
        state = (state is "true")
        @config.enabledEditing = state
        @jsonConfig.enabledEditing = state
        @framework.saveConfig()
        res.send 200, {
          success: true 
          message: (
            if state then __("You can now edit your list.") 
            else __("The list is now locked.")
          )
        }

      app.get '/remember', (req, res) =>
        rememberMe = req.query.rememberMe
        # rememberMe is handled by the framework, so see if it was picked up:
        if rememberMe is 'true' then rememberMe = yes
        if rememberMe is 'false' then rememberMe = no

        if req.session.rememberMe is rememberMe
          res.send 200, { success: true,  message: 'done' }
        else 
          res.send 200, {success: false, message: 'illegal param'}
        return
        
      app.post('/parseActions', (req, res) =>
        actionString = req.body.action
        error = null
        context =  null
        result = null
        try
          context = @framework.ruleManager.createParseContext()
          result = @framework.ruleManager.parseRuleActions("id", actionString, context)
          context.finalize()
        catch e
          error = e
          res.send 200, {success: false, error: error.message}
        unless error?
          for a in result.actions
            delete a.handler
          res.send 200, {
            success: true
            tokens: result.tokens
            actions: result.actions
            context
          }
      )

      app.post('/parseCondition', (req, res) =>
        conditionString = req.body.condition
        error = null
        context =  null
        result = null
        try
          context = @framework.ruleManager.createParseContext()
          result = @framework.ruleManager.parseRuleCondition("id", conditionString, context)
          context.finalize()
        catch e
          error = e
          res.send 200, {success: false, error: error.message}
        unless error?
          for p in result.predicates
            delete p.handler
          res.send 200, {
            success: true
            tokens: result.tokens
            predicates: result.predicates
            context
          }
      )


      app.get('/login', (req, res) =>
        url = req.query.url
        unless url then url = "/"
        res.redirect 302, url
      )

      certFile =  path.resolve(
        @framework.maindir, 
        '../..', 
        @framework.config.settings.httpsServer.rootCertFile
      )
      fs.exists certFile, (exists) => @hasRootCACert = exists
      app.get '/root-ca-cert.crt', (req, res) =>
        res.setHeader('content-type', 'application/x-x509-ca-cert')
        res.sendfile(certFile)

      # ###Socket.io stuff:
      # For every webserver
      for webServer in [app.httpServer, app.httpsServer]
        continue unless webServer?
        # Listen for new websocket connections
        io = socketIo.listen webServer, {
          logger: 
            log: (type, args...) ->
              if type isnt 'debug' then env.logger.log(type, 'socket.io:', args...)
            debug: (args...) -> this.log('debug', args...)
            info: (args...) -> this.log('info', args...)
            warn: (args...) -> this.log('warn', args...)
            error: (args...) -> this.log('error', args...)
        }

        sessionOptions = app.cookieSessionOptions
        ioCookieParser = express.cookieParser(sessionOptions.secret)
        # See http://howtonode.org/socket-io-auth for details
        io.set("authorization", (handshakeData, accept) =>
          if handshakeData.headers.cookie
            ioCookieParser(handshakeData, null, =>
              sessionCookie = handshakeData.signedCookies?[sessionOptions.key]
              auth = @framework.config.settings.authentication
              if sessionCookie? and sessionCookie.username is auth.username
                return accept(null, true)
              else 
                env.logger.debug "socket.io: Cookie is invalid."
                return accept(null, false)
            )
          else
            env.logger.warn "No cookie transmitted."
            return accept(null, false)      
        )

        # When a new client connects
        io.sockets.on('connection', (socket) =>

          initData = @getInitalClientData()
          socket.emit "welcome", initData

          for item in initData.items 
            do (item) =>
              switch item.type
                when "device" 
                  device = @framework.getDeviceById(item.deviceId)
                  @addAttributeNotify(socket, item)
                  for attr in item.attributes
                    do (attr) =>
                      device.getAttributeValue(attr.name).timeout(10000).then( (value) =>
                        @emitAttributeValue(socket, device, attr.name, value)
                      ).catch( (error) => 
                        env.logger.warn "Error getting #{attr.name} of #{item.id}: #{error.message}"
                        env.logger.debug error.stack
                      )


          env.logger.debug("adding rule listerns") if @config.debug
          framework.ruleManager.on "add", addRuleListener = (rule) =>
            @emitRuleUpdate socket, "add", rule
          
          framework.ruleManager.on "update", updateRuleListener = (rule) =>
            @emitRuleUpdate socket, "update", rule
         
          framework.ruleManager.on "remove", removeRuleListener = (rule) =>
            @emitRuleUpdate socket, "remove", rule

          env.logger.debug("adding log listern") if @config.debug
          memoryTransport = env.logger.transports.memory
          memoryTransport.on 'log', logListener = (entry)=>
            socket.emit 'log', entry

          env.logger.debug("adding item listers") if @config.debug

          @on 'item-add', addItemListener = (item) =>
            @addAttributeNotify(socket, item)
            socket.emit("item-add", item)

          @on 'item-remove', removeItemListener = (item) =>
            socket.emit("item-remove", item.itemId)
            
          @on 'item-order', orderItemListener = (order) =>
            socket.emit("item-order", order)

          @on 'rule-order', orderRuleListener = (order) =>
            socket.emit("rule-order", order)

          socket.on 'disconnect', => 
            env.logger.debug("removing rule listerns") if @config.debug
            framework.ruleManager.removeListener "update", updateRuleListener
            framework.ruleManager.removeListener "add", addRuleListener 
            framework.ruleManager.removeListener "update", removeRuleListener
            env.logger.debug("removing log listern") if @config.debug
            memoryTransport.removeListener 'log', logListener
            env.logger.debug("removing item-add listerns") if @config.debug
            @removeListener 'item-add', addItemListener
            @removeListener 'item-remove', removeItemListener
            @removeListener 'item-order', orderItemListener
            @removeListener 'rule-order', orderRuleListener
          return
        )
      # register the predicate provider
      ButtonPredicateProvider = require('./button-predicates') env
      @framework.ruleManager.addPredicateProvider(new ButtonPredicateProvider(this))

      @framework.on 'after init', (context)=>
        deferred = Q.defer()
        # Give the other plugins some time to register asset files
        process.nextTick => 
          # and then setup the assets and manifest
          try
            @setupAssetsAndManifest()
          catch e
            env.logger.error "Error setting up assets in mobile-frontend: #{e.message}"
            env.logger.debug e.stack
          finally
            deferred.resolve()

        finished = deferred.promise.then( =>
          # If we are ind evelopment mode then
          if @config.mode is "development"
            # render the index page at each load.
            @app.get '/', (req,res) =>
              @renderIndex().then( (html) =>
                res.send html
              ).catch( (error) =>
                env.logger.error error.message
                env.logger.debug error.stack
                res.send error
              ).done()
            return Q()
          else 
            # In production mode render the index page on time and store it to a file
            return @renderIndex().then( (html) =>
              indexFile = __dirname + '/public/index.html'
              Q.nfcall(fs.writeFile, indexFile, html)
            )
          )
        context.waitForIt finished
        return

    renderIndex: () ->
      env.logger.info "rendering html"
      jade = require('jade')

      renderOptions = 
        pretty: @config.mode is "development"
        compileDebug: @config.mode is "development"
        globals: ["__", "nap", "i18n"]
        mode: @config.mode

      awaitingRenders = 
        for page in @additionalAssetFiles['html']
          page = path.resolve __dirname, '..', page
          switch path.extname(page)
            when '.jade'
              env.logger.debug("rendering: #{page}") if @config.debug
              Q.ninvoke jade, 'renderFile', page, renderOptions
            when '.html'
              Q.nfcall fs.readFile, page
            else
              env.logger.error "Could not add page: #{page} unknown extension."
              Q ""

      Q.all(awaitingRenders).then( (htmlPages) =>
        renderOptions.additionalPages = _.reduce htmlPages, (html, page) => html + page
        layout = path.resolve __dirname, 'app/views/layout.jade' 
        env.logger.debug("rendering: #{layout}") if @config.debug
        Q.ninvoke(jade, 'renderFile', layout, renderOptions).then( (html) =>
          env.logger.info "rendering html finished"
          return html
        )
      )


    registerAssetFile: (type, file) ->
      assert type is 'css' or type is 'js' or type is 'html'
      assert not @assetsPacked, "Assets are already packed. Please call this function only from" +
        "the pimatic 'after init' event."
      @additionalAssetFiles[type].push file

    setupAssetsAndManifest: () ->

      parentDir = path.resolve __dirname, '..'

      # Returns p.min.file versions of p.file when it exist
      minPath = (p) => 
        # Check if a minimised version exists:
        if @config.mode is "production"
          minFile = p.replace(/\.[^\.]+$/, '.min$&')
          if fs.existsSync parentDir + "/" + minFile then return minFile
        # in other modes or when not exist return full file:
        return p



      themeCss = (
        if @config.theme is 'classic'
          [ "pimatic-mobile-frontend/app/css/themes/default/jquery.mobile.inline-svg-1.4.2.css",
            "pimatic-mobile-frontend/app/css/themes/default/jquery.mobile.structure-1.4.2.css" ]
        else if @config.theme is 'pimatic'
          [ "pimatic-mobile-frontend/app/css/themes/pimatic/jquery.mobile.icons.min.css",
            "pimatic-mobile-frontend/app/css/themes/pimatic/pimatic.css",
            "pimatic-mobile-frontend/app/css/themes/default/jquery.mobile.structure-1.4.2.css" ]        
        else
          [ "pimatic-mobile-frontend/app/css/themes/graphite/#{@config.theme}/" +
            "jquery.mobile-1.4.1.css" ]
      )

      # Configure static assets with nap
      console.log "nap mode", @config.mode
      nap(
        appDir: parentDir
        publicDir: "pimatic-mobile-frontend/public"
        mode: @config.mode
        minify: false # to slow...
        assets:
          js:
            jquery: [
              minPath "pimatic-mobile-frontend/app/js/jquery-1.10.2.js"
              minPath "pimatic-mobile-frontend/app/js/jquery.mobile-1.4.2.js"
              minPath "pimatic-mobile-frontend/app/js/jquery.mobile.toast.js"
              minPath "pimatic-mobile-frontend/app/js/jquery-ui-1.10.3.custom.js"
              minPath "pimatic-mobile-frontend/app/js/jquery.ui.touch-punch.js"
              minPath "pimatic-mobile-frontend/app/js/jquery.mobile.simpledialog2.js"
              minPath "pimatic-mobile-frontend/app/js/jquery.textcomplete.js"
              minPath "pimatic-mobile-frontend/app/js/jquery.storageapi.js"
              minPath "pimatic-mobile-frontend/app/js/knockout-3.1.0.js"
              minPath "pimatic-mobile-frontend/app/js/knockout.mapping.js"
            ]
            main: [
              "pimatic-mobile-frontend/app/scope.coffee"
              "pimatic-mobile-frontend/app/helper.coffee"
              "pimatic-mobile-frontend/app/knockout-custom-bindings.coffee"
              "pimatic-mobile-frontend/app/connection.coffee"
              "pimatic-mobile-frontend/app/pages/index-items.coffee"
              "pimatic-mobile-frontend/app/pages/*"
            ] .concat (minPath(f) for f in @additionalAssetFiles['js'])
            
          css:
            theme: [
              minPath "pimatic-mobile-frontend/app/css/theme/default/jquery.mobile-1.4.2.css"
            ] .concat ( minPath t for t in themeCss ) .concat [
              minPath "pimatic-mobile-frontend/app/css/jquery.mobile.toast.css"
              minPath "pimatic-mobile-frontend/app/css/jquery.mobile.simpledialog.css"
              minPath "pimatic-mobile-frontend/app/css/jquery.textcomplete.css"
            ] 
            style: [
              "pimatic-mobile-frontend/app/css/style.css"
            ] .concat (minPath(f) for f in @additionalAssetFiles['css'])
      )

      nap.preprocessors['.coffee'] = (contents, filename) ->
        try
          coffee.compile contents, bare: on
        catch err
          err.stack = "Nap error compiling #{filename}\n" + err.stack
          throw err


      # When the config mode 
      manifest = (switch @config.mode 
        # is production
        when "production"
          # then pack the static assets in "public/assets/"
          env.logger.info "packing static assets"
          nap.package()
          env.logger.info "packing static assets finished"
          renderManifest = require "render-appcache-manifest"
          # function to create the app manifest
          createAppManifest = =>
            # Collect all files in "public"
            assets = []
            for f in fs.readdirSync  __dirname + '/public/assets'
              assets.push "/assets/#{f}"
            for f in fs.readdirSync  __dirname + '/public'
              if not (f in ['index.html', 'info.md']) and
              fs.lstatSync("#{__dirname}/public/#{f}").isFile()
                assets.push "/#{f}"

            # render the app manifest
            return renderManifest(
              cache: assets.concat [
                '/',
                '/socket.io/socket.io.js'
              ]
              network: ['*']
              fallback: []
              lastModified: new Date()
            )
          # Save the manifest. We don't need to generate it each request, because
          # files shouldn't change in production mode
          manifest = createAppManifest()
        # if we are in development mode
        when "development"
          # then serve the files directly
          @app.use nap.middleware
          # and cache nothing
          manifest = """
            CACHE MANIFEST
            NETWORK:
            *
          """
        else 
          env.logger.error "Unknown mode: #{@config.mode}!"
          ""
      )

      # * Static assets
      app.use express.static(__dirname + "/public")

      # If the app manifest is requested
      @app.get "/application.manifest", (req, res) =>
        # then deliver it
        res.statusCode = 200
        res.setHeader "content-type", "text/cache-manifest"
        res.setHeader "content-length", Buffer.byteLength(manifest)
        res.end manifest

    addNewItem: (item) ->
      @config.items.push item
      @jsonConfig.items = @config.items
      @framework.saveConfig()

      item = (
        switch item.type
          when 'device' then @getDeviceWithData(item)
          when 'header', 'button'
            item.template = item.type
            item
      )

      @emit 'item-add', item 

    addAttributeNotify: (socket, item) ->
      device = @framework.getDeviceById item.deviceId
      unless device? 
        env.logger.debug "device #{item.deviceId} not found."
        return
      for attr in device.attributes 
        do (attr) =>
          env.logger.debug("adding listener for #{attr.name} of #{device.id}") if @config.debug
          device.on attr.name, attrListener = (value) =>
            env.logger.debug("attr change for #{attr.name} of #{device.id}: #{value}") if @config.debug
            @emitAttributeValue socket, device, attr.name, value
          socket.on 'disconnect', => 
            env.logger.debug("removing listener for #{attr} of #{device.id}") if @config.debug
            device.removeListener attr.name, attrListener
      return

    getItemsWithData: () ->
      items = []
      for item in @config.items
        do (item) =>
          switch item.type
            when "device"
              item = @getDeviceWithData(item)
              items.push item
            when "header", 'button'
              item.template = item.type
              items.push item
            else
              errorMsg = "Unknown item type \"#{item.type}\""
              env.logger.error errorMsg
      return items

    getDeviceWithData: (item) ->
      assert item.type is "device"
      assert item.deviceId?
      device = @framework.getDeviceById item.deviceId
      if device?
        item =
          itemId: item.itemId
          type: "device"
          deviceId: device.id
          name: device.name
          template: device.getTemplateName()
          attributes: []

        typeToString = (type) => 
          if typeof type is "function" then type.name.toLowerCase()
          else if Array.isArray type then "string"
          else "unknown"

        for name, attr of device.attributes
          itemAttribute = _.cloneDeep(attr)
          itemAttribute.name = name
          itemAttribute.type = typeToString(attr.type)
          item.attributes.push itemAttribute

        return item
      else
        errorMsg = "No device to display with id \"#{item.deviceId}\" found"
        env.logger.error errorMsg
        return item = {
          type: "device"
          deviceId: item.deviceId
          name: ""
          template: "device"
          attributes: []
          error: errorMsg
        }

    getRules: () =>
      rules = []
      for id of @framework.ruleManager.rules
        rule = @framework.ruleManager.rules[id]
        rules.push {
          id: id
          condition: rule.conditionToken
          action: rule.actionsToken
          active: rule.active
          valid: rule.valid
          error: rule.error
        }

      # sort rules by ordering in config
      order = _(@config.rules).map( (r) => r.id )
      rules = _(rules).sortBy( (r) => 
        index = order.indexOf r.id
        # push it to the end if not found
        return if index is -1 then 99999 else index 
      ).value()

    getInitalClientData: () ->
      return {
        errorCount: env.logger.transports.memory.getErrorCount()
        enabledEditing: @config.enabledEditing
        hasRootCACert: @hasRootCACert
        items: @getItemsWithData()
        rules: @getRules()
      }      

    emitRuleUpdate: (socket, trigger, rule) ->
      socket.emit "rule-#{trigger}",
        id: rule.id
        condition: rule.conditionToken
        action: rule.actionsToken
        active: rule.active
        valid: rule.valid

    emitAttributeValue: (socket, device, name, value) ->
      socket.emit "device-attribute",
        id: device.id
        name: name
        value: value

    genItemId: (prefix, baseText, existingItems = @config.items) ->
      existingIds = _(existingItems).map( (item) => item.itemId ).filter( (id) => id? ).value()
      newId = prefix + "-" + S(baseText).slugify().s
      unless newId in existingIds then return newId
      num = 2
      newIdWithNum = newId + num
      while newIdWitNum in existingIds
        num++
        newIdWithNum = newId + num
      return newIdWitNum

  plugin = new MobileFrontend
  return plugin