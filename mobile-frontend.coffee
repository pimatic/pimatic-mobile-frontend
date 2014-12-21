module.exports = (env) ->

  # ##Dependencies
  # * from node.js
  util = require 'util'
  fs = require 'fs'
  path = require 'path'

  # * pimatic imports.
  Promise = env.require 'bluebird'
  Promise.promisifyAll(fs)
  assert = env.require 'cassert'
  express = env.require "express" 
  S = env.require 'string'
  M = env.matcher

  global.i18n = env.require('i18n')
  global.__ = i18n.__
  _ = env.require 'lodash'
  crypto = require 'crypto'

  # * own
  # socketIo = require 'socket.io'
  global.nap = require 'nap'
  jqmthemer = require 'jqmthemer'

  # ##The MobileFrontend
  class MobileFrontend extends env.plugins.Plugin
    additionalAssetFiles:
      'js': []
      'css': []
      'html': []
    assetsPacked: no

    # ###init the frontend:
    init: (@app, @framework, @config) ->

      if @config.theme in ["aloe", "candy", "melon", "mint", "royal", "sand", "slate", "water"]
        @config.theme = "graphite/#{@config.theme}"
      if @config.theme is "classic"
        @config.theme = "jqm/#{@config.theme}" 

      themesWithLegazy = require('./mobile-frontend-config-schema').properties.theme.enum
      @themes = []
      for theme in themesWithLegazy
        if theme.indexOf('/') is -1 then continue
        @themes.push theme
      
      app.post('/client-error', (req, res) =>
        error = req.body.error
        env.logger.error("Client error:", error.message)
        env.logger.debug JSON.stringify(error, null, "  ")
        res.send 200
      )

      app.get('/refresh', (req, res) =>
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

      @setupThemes()

      @framework.on 'after init', (context)=>
        finished = Promise.resolve().then( =>
          # and then setup the assets and manifest
          try
            assets = @setupAssets()
          catch e
            env.logger.error "Error setting up assets in mobile-frontend: #{e.message}"
            env.logger.debug e.stack
            return
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
            return
          else 
            # In production mode render the index page on time and store it to a file
            return @renderIndex().then( (html) =>
              indexFile = __dirname + '/public/index.html'
              fs.writeFileAsync(indexFile, html)
              @setupManifest(assets, html)
            )
          
        )

        context.waitForIt finished
        return

    renderIndex: () ->
      env.logger.info "rendering html"
      jade = require('jade')
      Promise.promisifyAll(jade)

      theme = {
        flat: @config.flat
        headerSwatch: 'a'
        dividerSwatch: 'a'
        menuSwatch: 'f'
        fullName: @config.theme
      }

      renderOptions = {
        pretty: @config.mode is "development"
        compileDebug: @config.mode is "development"
        globals: ["__", "nap", "i18n"]
        mode: @config.mode,
        api: env.api.all
        customTitle: @config.customTitle
        theme
      }

      awaitingRenders = 
        for page in @additionalAssetFiles['html']
          page = path.resolve __dirname, '..', page
          switch path.extname(page)
            when '.jade'
              env.logger.debug("rendering: #{page}") if @config.debug
              jade.renderFileAsync page, renderOptions
            when '.html'
              fs.readFileAsync page
            else
              env.logger.error "Could not add page: #{page} unknown extension."
              Promise.resolve ""

      return Promise.all(awaitingRenders).then( (htmlPages) =>
        renderOptions.additionalPages = _.reduce htmlPages, (html, page) => html + page
        layout = path.resolve __dirname, 'app/views/layout.jade' 
        env.logger.debug("rendering: #{layout}") if @config.debug
        return jade.renderFileAsync(layout, renderOptions).then( (html) =>
          env.logger.info "rendering html finished"
          return html
        )
      )


    registerAssetFile: (type, file) ->
      assert type is 'css' or type is 'js' or type is 'html'
      assert not @assetsPacked, "Assets are already packed. Please call this function only from" +
        "the pimatic 'after init' event."
      @additionalAssetFiles[type].push file

    setupAssets: () ->
      parentDir = path.resolve __dirname, '..'

      # Configure static assets with nap
      napAssets = nap(
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
              "pimatic-mobile-frontend/app/js/jquery.textcomplete.js"
              "pimatic-mobile-frontend/app/js/jquery.storageapi.js"
              "pimatic-mobile-frontend/app/js/knockout-3.2.0.js"
              "pimatic-mobile-frontend/app/js/knockout.mapper.js"
              "pimatic-mobile-frontend/app/js/overthrow.js"
              "pimatic-mobile-frontend/app/js/jsoneditor-schema.js"
              "pimatic-mobile-frontend/app/js/owl.carousel.js"
              "pimatic-mobile-frontend/app/js/highstock.js"
              "pimatic-mobile-frontend/app/js/touch-tooltip-fix.js"
              "pimatic-mobile-frontend/app/js/jquery.ui.datepicker.js"
              "pimatic-mobile-frontend/app/js/jquery.mobile.datepicker.mod.js"
              "pimatic-mobile-frontend/app/js/jquery.sparkline.js"
              "pimatic-mobile-frontend/app/js/human-format.js"
              "pimatic-mobile-frontend/app/js/sweet-alert.js"
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
              "pimatic-mobile-frontend/app/pages/edit-group.coffee"
              "pimatic-mobile-frontend/app/pages/edit-device.coffee"
              "pimatic-mobile-frontend/app/pages/index.coffee"
              "pimatic-mobile-frontend/app/pages/login.coffee"
              "pimatic-mobile-frontend/app/pages/rules.coffee"
              "pimatic-mobile-frontend/app/pages/groups.coffee"
              "pimatic-mobile-frontend/app/pages/devicepages.coffee"
              "pimatic-mobile-frontend/app/pages/devices.coffee"
              "pimatic-mobile-frontend/app/pages/variables.coffee"
              "pimatic-mobile-frontend/app/pages/log-messages.coffee"
              "pimatic-mobile-frontend/app/pages/events.coffee"
              "pimatic-mobile-frontend/app/pages/plugins.coffee"
              "pimatic-mobile-frontend/app/pages/config.coffee"
              "pimatic-mobile-frontend/app/pages/updates.coffee"
              "pimatic-mobile-frontend/app/pages/edit-devicepage.coffee"
              "pimatic-mobile-frontend/app/pages/graph.coffee"
            ] .concat @additionalAssetFiles['js']
            editor: [
              "pimatic-mobile-frontend/app/js/jsoneditor.js"
              "pimatic-mobile-frontend/app/js/ace.js"
              "pimatic-mobile-frontend/app/js/jsonlint.js"
            ]
          css:
            base: [
              "pimatic-mobile-frontend/app/css/theme/default/jquery.mobile-1.4.2.css"
            # ] .concat themeCss .concat [
              "pimatic-mobile-frontend/app/css/jquery.mobile.toast.css"
              "pimatic-mobile-frontend/app/css/jquery.mobile.datepicker.css"
              "pimatic-mobile-frontend/app/css/jquery.textcomplete.css"
              "pimatic-mobile-frontend/app/css/owl.carousel.css"
              "pimatic-mobile-frontend/app/css/sweet-alert.css"
            ] 
            style: [
              "pimatic-mobile-frontend/app/css/jqm-icon-pack-fa.css"
            ] .concat @additionalAssetFiles['css']
            editor: [
               "pimatic-mobile-frontend/app/css/jsoneditor.css"
            ]
      )

      # Returns p.min.file versions of p.file when it exist
      minPath = (p) => 
        # Check if a minimised version exists:
        minFile = p.replace(/\.[^\.]+$/, '.min$&').replace(/\.coffee$/,'.js')
        if fs.existsSync(parentDir + "/" + minFile) then return minFile
        # in other modes or when not exist return full file:
        return p

      if @config.mode is "production"
        for sec, files of napAssets.assets.js
          for f, i in files
            files[i] = minPath f

        # make absolute pathes to relative ones on windows
        for assetType of napAssets.assets
          for sec, files of napAssets.assets[assetType]
            for f, i in files
              # continue if already relative
              unless S(f).startsWith(parentDir.replace(/\\/g,'/')) then continue
              files[i] = path.relative(parentDir, f)

        # then pack the static assets in "public/assets/"
        env.logger.info "packing static assets"
        nap.package()
        env.logger.info "packing static assets finished"

      # Collect all files in "public" and other static content
      assets = [
        '/',
        '/socket.io/socket.io.js'
        '/api/decl-api-client.js'
      ]
      for f in fs.readdirSync  __dirname + '/public/assets'
        assets.push "/assets/#{f}"
      for f in fs.readdirSync  __dirname + '/public'
        if not (f in ['index.html', 'info.md']) and
        fs.lstatSync("#{__dirname}/public/#{f}").isFile()
          assets.push "/#{f}"

      @framework.userManager.addAllowPublicAccessCallback( (req) =>
        return (
          req.url.match(/^\/socket\.io\/.*$/)? or 
          (req.url in assets) or 
          (req.url is '/application.manifest') or
          req.url.match(/^\/theme\/.*\.css(\?.*)?$/)? 
        )
      )

      if @config.mode is "development"
        @framework.userManager.addAllowPublicAccessCallback( (req) =>
          return req.url.match(/^\/assets\/.*$/)?
        )

      if @config.mode is "development"
        # then serve the files directly
        @app.use nap.middleware

      # * Static assets
      @app.use express.static(__dirname + "/public")

      return assets

    createThemeCss: (themeName) ->
      theme = require "./themes/#{themeName}"
      # concate all css
      cssFiles = _.clone(theme.css)
      cssFiles.push "app/css/style.css"
      cssFiles = cssFiles.concat theme.extraCss
      return Promise.map(cssFiles, (cssFile) =>
        return fs.readFileAsync(__dirname + "/#{cssFile}")
      ).reduce( (fullCss, css) =>
        fullCss += css;
      ).then( (css) ->
        return jqmthemer.themeCss theme, css 
      )

    setupThemes: () ->
      @app.get "/theme/:themeBase/:themeSub.css", (req, res) =>
        themeBase = req.params.themeBase
        themeSub = req.params.themeSub
        themeFullName = "#{themeBase}/#{themeSub}"
        unless themeFullName in @themes
          res.statusCode = 404
          res.end()
          return

        cachePath = __dirname + "/public/theme-#{themeBase}-#{themeSub}.css"
        
        if req.query.save
          # Save theme to session so that we can deliver the correct theme in the app manifest
          req.session.theme = themeFullName

        serveTheme = (css) ->
          res.statusCode = 200
          res.setHeader "content-type", "text/css"
          res.setHeader "content-length", Buffer.byteLength(css)
          res.end css

        if @mode is "production"
          fs.readFileAsync(cachePath)
            .then( (css) -> serveTheme(css.toString()) )
            .catch( (error) =>
              if error.code is 'ENOENT' 
                return @createThemeCss(themeFullName).then( (css) ->
                  fs.writeFileAsync(cachePath).then( ->
                    serveTheme(css)
                  )
                )
              else
                throw error
            )
            .done()
        else
          # always rerender theme in production mode
          @createThemeCss(themeFullName).then( (css) -> serveTheme(css) ).done()

    setupManifest: (assets, indexHtml)->
      parentDir = path.resolve __dirname, '..'
      # When the config mode 
      manifest = (switch @config.mode 
        # is production
        when "production"
          pimaticLastUpdate = fs.statSync(
            "#{parentDir}/pimatic/package.json"
          ).mtime
          mobilefrontentLastupdate = fs.statSync(
            "#{parentDir}/pimatic-mobile-frontend/package.json"
          ).mtime

          lastModified = (
            if pimaticLastUpdate > mobilefrontentLastupdate
            then pimaticLastUpdate
            else mobilefrontentLastupdate
          ) 

          md5 = crypto.createHash('md5')
          md5.update indexHtml
          indexMD5 = md5.digest('hex')

          renderManifest = require "render-appcache-manifest"
          # function to create the app manifest
          createAppManifest = =>
            # render the app manifest
            return renderManifest(
              cache: assets.concat [
                "/theme/#{@config.theme}.css"
                "/theme/THEMENAME.css?save=1"
              ]
              network: ['*']
              fallback: []
              lastModified: lastModified
              comment: indexMD5
            )
          # Save the manifest. We don't need to generate it each request, because
          # files shouldn't change in production mode
          manifest = createAppManifest()
        # if we are in development mode
        when "development"
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

      # If the app manifest is requested
      @app.get "/application.manifest", (req, res) =>
        themeName = @config.theme
        if req.session.theme? and req.session.theme in @themes
          themeName = req.session.theme
        customManifest = manifest.replace('THEMENAME', themeName)
        # then deliver it
        res.statusCode = 200
        res.setHeader "content-type", "text/cache-manifest"
        res.setHeader "content-length", Buffer.byteLength(customManifest)
        res.end customManifest

  plugin = new MobileFrontend
  return plugin