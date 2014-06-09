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
  # socketIo = require 'socket.io'
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

      conf.load @jsonConfig
      conf.validate()
      @config = conf.get ""
        
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
      Handle get request for add a variable to the item list.
      ###
      app.get('/add-variable/:name', (req, res) =>
        name = req.params.name
        # If no text is given then send an error.
        if name is ""
          return res.send(200, {success: false, message: 'no variable name given'})
        # else add the item to the item list and send success
        itemId = @genItemId('variable', name)
        @addNewItem({
          itemId: itemId
          type: 'variable'
          name: name
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

        item = _(@jsonConfig.items).find({itemId: itemId})
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
      Handle post request for updating the variables list sorting.
      ###
      app.post('/update-variable-order', (req, res) =>
        order = req.body.order
        unless order?
          res.send 200, {success: false, message: 'no order given'}
          return
        @config.variables = @jsonConfig.variables = _(order).map( (name)=> {name}).value()
        @framework.saveConfig()
        @emit 'variable-order', order
        res.send 200, {success: true}
      )
    
      ###
      Handle get request for clearing the log
      ###
      # app.get('/clear-log', (req, res) =>
      #   # TODO: clear?
      #   res.send(200, {success: true})
      # )

      ###
      Handle get request for button press
      ###
      app.get('/button-pressed/:buttonId', (req, res) =>
        buttonId = req.params.buttonId
        item = _(@config.items).find({type: 'button', buttonId: buttonId})
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

      app.get '/showAttributeVars/:state', (req, res) =>
        state = req.params.state
        state = (state is "true")
        @config.showAttributeVars = state
        @jsonConfig.showAttributeVars = state
        @framework.saveConfig()
        res.send 200, {
          success: true 
          message: (
            if state then __("Showing variables for device attributes.") 
            else __("Hiding variables for device attributes.")
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

      app.post('/client-error', (req, res) =>
        error = req.body.error
        env.logger.error("Client error:", error.message)
        env.logger.debug JSON.stringify(error, null, "  ")
        res.send 200
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

      @setupUpdateProcessListener()

      socketIOLogger = env.logger.createSublogger('socket.io')
      # mute debug outs
      socketIOLogger = new Object(socketIOLogger)
      socketIOLogger.debug = -> #nop

      # ###Socket.io stuff:
      # For every webserver
      # for webServer in [app.httpServer, app.httpsServer]
      #   continue unless webServer?
      #   # Listen for new websocket connections
      #   io = socketIo.listen webServer, {
      #     logger: socketIOLogger
      #   }

      #   sessionOptions = app.cookieSessionOptions
      #   ioCookieParser = express.cookieParser(sessionOptions.secret)
      #   unless @framework.config.settings.authentication.enabled is false
      #     # See http://howtonode.org/socket-io-auth for details
      #     io.set("authorization", (handshakeData, accept) =>
      #       if handshakeData.headers.cookie
      #         ioCookieParser(handshakeData, null, =>
      #           sessionCookie = handshakeData.signedCookies?[sessionOptions.key]
      #           auth = @framework.config.settings.authentication
      #           if sessionCookie? and sessionCookie.username is auth.username
      #             return accept(null, true)
      #           else 
      #             env.logger.debug "socket.io: Cookie is invalid."
      #             return accept(null, false)
      #         )
      #       else
      #         env.logger.warn "No cookie transmitted."
      #         return accept(null, false)      
      #     )

      #   # When a new client connects
      #   io.sockets.on('connection', (socket) =>

      #     initData = @getInitalClientData()
      #     socket.emit "welcome", initData

      #     for item in initData.items 
      #       do (item) =>
      #         switch item.type
      #           when "device" 
      #             device = @framework.getDeviceById(item.deviceId)
      #             @addAttributeNotify(socket, item)

      #     for variable in initData.variables
      #       do (variable) =>
      #         @framework.variableManager.getVariableValue(variable.name).then( (value) =>
      #           @emitVariableChange(socket, {name: variable.name, value})
      #         ).catch( (error) => 
      #           env.logger.warn "Error getting value of #{variable.name}"
      #           env.logger.debug error.stack
      #         )
          
      #     env.logger.debug("adding listener for variables") if @config.debug
      #     @framework.variableManager.on('change', varChangeListener = (varInfo) =>
      #       env.logger.debug("var change for #{varInfo.name}: #{varInfo.value}") if @config.debug
      #       @emitVariableChange(socket, varInfo)
      #     )

      #     @framework.variableManager.on('add', varAddListener = (varInfo) =>
      #       socket.emit("variable-add", varInfo)
      #     )

      #     @framework.variableManager.on('remove', varRemoveListener = (name) =>
      #       socket.emit("variable-remove", name)
      #     )

        #   socket.on('disconnect', => 
        #     env.logger.debug("removing variables listener") if @config.debug
        #     @framework.variableManager.removeListener('change', varChangeListener)
        #     @framework.variableManager.removeListener('add', varAddListener)
        #     @framework.variableManager.removeListener('remove', varRemoveListener)
        #   )


        #   env.logger.debug("adding rule listerns") if @config.debug
        #   framework.ruleManager.on "add", addRuleListener = (rule) =>
        #     @emitRuleUpdate socket, "add", rule
          
        #   framework.ruleManager.on "update", updateRuleListener = (rule) =>
        #     @emitRuleUpdate socket, "update", rule
         
        #   framework.ruleManager.on "remove", removeRuleListener = (rule) =>
        #     socket.emit "rule-remove", rule.id

        #   env.logger.debug("adding log listern") if @config.debug
        #   #todo: filter
        #   @framework.database.on 'log', logListener = (entry)=>
        #     socket.emit 'log', entry

        #   env.logger.debug("adding item listers") if @config.debug

        #   @on 'item-add', addItemListener = (item) =>
        #     assert item? and item.itemId?
        #     switch item.type
        #       when 'device' then @addAttributeNotify(socket, item)
        #       when 'variable'
        #         @framework.variableManager.getVariableValue(item.name).then( (value) =>
        #           @emitVariableChange(socket, {name: item.name, value})
        #         ).catch( (error) => 
        #           env.logger.warn "Error getting value of #{item.name}"
        #           env.logger.debug error.stack
        #         )
        #     socket.emit("item-add", item)

        #   @on 'item-remove', removeItemListener = (item) =>
        #     assert item? and item.itemId?
        #     socket.emit("item-remove", item.itemId)
            
        #   @on 'item-order', orderItemListener = (order) =>
        #     assert order? and Array.isArray order
        #     socket.emit("item-order", order)

        #   @on 'rule-order', orderRuleListener = (order) =>
        #     assert order? and Array.isArray order
        #     socket.emit("rule-order", order)

        #   @on 'variable-order', orderVariablesListener = (order) =>
        #     assert order? and Array.isArray order
        #     socket.emit("variable-order", order)

        #   @on('update-process-status', onUpdateProcessStatus = (status) =>
        #     socket.emit 'update-process-status', status
        #   )

        #   @on('update-process-message', onUpdateProcessMessage = (message) =>
        #     socket.emit 'update-process-message', message
        #   )

        #   socket.on 'disconnect', => 
        #     env.logger.debug("removing rule listerns") if @config.debug
        #     framework.ruleManager.removeListener "update", updateRuleListener
        #     framework.ruleManager.removeListener "add", addRuleListener 
        #     framework.ruleManager.removeListener "update", removeRuleListener
        #     env.logger.debug("removing log listern") if @config.debug
        #     @framework.database.removeListener 'log', logListener
        #     env.logger.debug("removing item-add listerns") if @config.debug
        #     @removeListener 'item-add', addItemListener
        #     @removeListener 'item-remove', removeItemListener
        #     @removeListener 'item-order', orderItemListener
        #     @removeListener 'rule-order', orderRuleListener
        #     @removeListener 'variable-order', orderVariablesListener
        #     @removeListener 'update-process-status', onUpdateProcessStatus
        #     @removeListener 'update-process-message', onUpdateProcessMessage
        #   return
        # )
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

      theme = {
        headerSwatch: 'a'
        dividerSwatch: 'a'
        menuSwatch: 'f'
      }

      renderOptions = {
        pretty: @config.mode is "development"
        compileDebug: @config.mode is "development"
        globals: ["__", "nap", "i18n"]
        mode: @config.mode,
        api: env.api.all
        theme
      }

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

    setupUpdateProcessListener: () ->
      pm = @framework.pluginManager

      pm.on('update-start', (info) =>
        @updateProcessMessages = []
        @updateProcessStatus = 'running'
        @emit 'update-process-status', 'running'
      )
      pm.on('update-info', (info) =>
        @updateProcessMessages.push info.message
        @emit 'update-process-message', info.message
      )
      pm.on('update-done', (info) =>
        @updateProcessStatus = 'done'
        @emit 'update-process-status', 'done'
      )
      pm.on('update-error', (info) =>
        @updateProcessMessages.push info.error.message
        @updateProcessStatus = 'error'
        @emit 'update-process-status', 'error'
      )


    registerAssetFile: (type, file) ->
      assert type is 'css' or type is 'js' or type is 'html'
      assert not @assetsPacked, "Assets are already packed. Please call this function only from" +
        "the pimatic 'after init' event."
      @additionalAssetFiles[type].push file

    setupAssetsAndManifest: () ->

      parentDir = path.resolve __dirname, '..'

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
            "jquery.mobile-1.4.2.css" ]
      )

      # Configure static assets with nap
      napAsserts = nap(
        appDir: parentDir
        publicDir: "pimatic-mobile-frontend/public"
        mode: @config.mode
        minify: false # to slow...
        assets:
          js:
            jquery: [
              "pimatic-mobile-frontend/app/js/tracekit.js"
              "pimatic-mobile-frontend/app/js/jquery-1.10.2.js"
              "pimatic-mobile-frontend/app/mobile-init.js"
              "pimatic-mobile-frontend/app/js/jquery.mobile-1.4.2.js"
              "pimatic-mobile-frontend/app/js/jquery.mobile.toast.js"
              "pimatic-mobile-frontend/app/js/jquery.pep.js"
              "pimatic-mobile-frontend/app/js/jquery.mobile.simpledialog2.js"
              "pimatic-mobile-frontend/app/js/jquery.textcomplete.js"
              "pimatic-mobile-frontend/app/js/jquery.storageapi.js"
              "pimatic-mobile-frontend/app/js/knockout-3.1.0.js"
              "pimatic-mobile-frontend/app/js/knockout.mapping.js"
              "pimatic-mobile-frontend/app/js/overthrow.js"
              "pimatic-mobile-frontend/app/js/owl.carousel.js"
            ]
            main: [
              "pimatic-mobile-frontend/app/scope.coffee"
              "pimatic-mobile-frontend/app/helper.coffee"
              "pimatic-mobile-frontend/app/knockout-custom-bindings.coffee"
              "pimatic-mobile-frontend/app/connection.coffee"
              "pimatic-mobile-frontend/app/pages/index-items.coffee"
              "pimatic-mobile-frontend/app/pages/add-item.coffee"
              "pimatic-mobile-frontend/app/pages/edit-rule.coffee"
              "pimatic-mobile-frontend/app/pages/edit-variable.coffee"
              "pimatic-mobile-frontend/app/pages/edit-groups.coffee"
              "pimatic-mobile-frontend/app/pages/index.coffee"
              "pimatic-mobile-frontend/app/pages/rules.coffee"
              "pimatic-mobile-frontend/app/pages/variables.coffee"
              "pimatic-mobile-frontend/app/pages/log-messages.coffee"
              "pimatic-mobile-frontend/app/pages/events.coffee"
              "pimatic-mobile-frontend/app/pages/plugins.coffee"
              "pimatic-mobile-frontend/app/pages/updates.coffee"
              "pimatic-mobile-frontend/app/pages/edit-devicepage.coffee"
            ] .concat @additionalAssetFiles['js']
            
          css:
            theme: [
              "pimatic-mobile-frontend/app/css/theme/default/jquery.mobile-1.4.2.css"
            ] .concat themeCss .concat [
              "pimatic-mobile-frontend/app/css/jquery.mobile.toast.css"
              "pimatic-mobile-frontend/app/css/jquery.mobile.simpledialog.css"
              "pimatic-mobile-frontend/app/css/jquery.textcomplete.css"
              "pimatic-mobile-frontend/app/css/owl.carousel.css"
              #"pimatic-mobile-frontend/app/css/owl.theme.css"
            ] 
            style: [
              "pimatic-mobile-frontend/app/css/style.css"
            ] .concat @additionalAssetFiles['css']
      )

      # Returns p.min.file versions of p.file when it exist
      minPath = (p) => 
        # Check if a minimised version exists:
        minFile = p.replace(/\.[^\.]+$/, '.min$&').replace(/\.coffee$/,'.js')
        if fs.existsSync(parentDir + "/" + minFile) then return minFile
        # in other modes or when not exist return full file:
        return p

      if @config.mode is "production"
        for sec, files of napAsserts.assets.js
          for f, i in files
            files[i] = minPath f

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
      @app.use express.static(__dirname + "/public")

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
          when 'variable'
            item.template = 'variable'
            item
          else item
      )

      @emit 'item-add', item 

    # addAttributeNotify: (socket, item) ->
    #   device = @framework.getDeviceById(item.deviceId)
    #   unless device? 
    #     env.logger.debug "device #{item.deviceId} not found."
    #     return
    #   for attrName, attr of device.attributes 
    #     do (attrName, attr) =>
    #       env.logger.debug("adding listener for #{attrName} of #{device.id}") if @config.debug
    #       device.on attrName, attrListener = (value) =>
    #         if @config.debug
    #           env.logger.debug("attr change for #{attrName} of #{device.id}: #{value}") 
    #         @emitAttributeValue socket, device, attrName, value
    #       socket.on 'disconnect', => 
    #         env.logger.debug("removing listener for #{attrName} of #{device.id}") if @config.debug
    #         device.removeListener attrName, attrListener
    #       device.getAttributeValue(attrName).timeout(10000).then( (value) =>
    #         @emitAttributeValue(socket, device, attrName, value)
    #       ).catch( (error) => 
    #         env.logger.warn "Error getting #{attrName} of #{device.id}: #{error.message}"
    #         env.logger.debug error.stack
    #       )
    #   return

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
            when "variable"
              item.template = "variable"
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
          else if Array.isArray type then 'string'
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
          itemId: item.itemId
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
          name: rule.name
          condition: rule.conditionToken
          action: rule.actionsToken
          active: rule.active
          valid: rule.valid
          logging: rule.logging
          error: rule.error
        }

      # sort rules by ordering in config
      order = _(@config.rules).map( (r) => r.id )
      rules = _(rules).sortBy( (r) => 
        index = order.indexOf r.id
        # push it to the end if not found
        return if index is -1 then 99999 else index 
      ).value()

    getVariables: () =>
      variables = @framework.variableManager.getAllVariables()
      # sort rules by ordering in config
      order = _(@config.variables).map( (r) => r.name )
      variables = _(variables).sortBy( (r) => 
        index = order.indexOf r.name
        # push it to the end if not found
        return if index is -1 then 99999 else index 
      ).value()

    getInitalClientData: () ->
      return {
        ruleItemCssClass: @config.ruleItemCssClass
        errorCount: 0 #TODO //env.logger.transports.memory.getErrorCount()
        enabledEditing: @config.enabledEditing
        showAttributeVars: @config.showAttributeVars
        hasRootCACert: @hasRootCACert
        updateProcessStatus: @updateProcessStatus
        updateProcessMessages: @updateProcessMessages
        items: @getItemsWithData()
        rules: @getRules()
        variables: @getVariables()
      }      

    emitRuleUpdate: (socket, trigger, rule) ->
      socket.emit "rule-#{trigger}", {
        id: rule.id
        name: rule.name
        condition: rule.conditionToken
        action: rule.actionsToken
        active: rule.active
        valid: rule.valid
        logging: rule.logging
      }

    emitAttributeValue: (socket, device, name, value) ->
      socket.emit "device-attribute", {
        id: device.id
        name: name
        value: value
      }

    emitVariableChange: (socket, varInfo) ->
      socket.emit "variable", varInfo

    genItemId: (prefix, baseText, existingItems = @config.items) ->
      existingIds = _(existingItems).map( (item) => item.itemId ).filter( (id) => id? ).value()
      newId = prefix + "-" + S(baseText).slugify().s
      unless newId in existingIds then return newId
      num = 2
      newIdWithNum = newId + num
      while newIdWithNum in existingIds
        num++
        newIdWithNum = newId + num
      return newIdWithNum

  plugin = new MobileFrontend
  return plugin