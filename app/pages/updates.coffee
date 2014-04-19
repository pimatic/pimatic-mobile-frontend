# updates-page
# ---------


# log-page
# ---------

$(document).on("pagecreate", '#updates', (event) ->

  class UpdateViewModel

    pimaticUpdateInfo: ko.observable(null)
    outdatedPlugins: ko.observableArray(null)

    constructor: ->
      index = pimatic.pages.index
      @updateProcessStatus = index.updateProcessStatus
      @updateProcessMessages = index.updateProcessMessages

      @hasUpdates = ko.computed( =>
        return (@pimaticUpdateInfo()?.isOutdated) or (@outdatedPlugins().length > 0)
      )

      @pimaticUpdateInfoText = ko.computed( =>
        info = @pimaticUpdateInfo()
        unless info? then return ''
        if info.isOutdated
          return __('Found update for %s: current version is %s, latest version is: %s', 
            'pimatic', 
            info.isOutdated.current, 
            info.isOutdated.latest
          )
        else
          return __('pimatic is up to date.')
      )

      @pluginUpdateInfoText = ko.computed( =>
        op = @outdatedPlugins()
        unless op? then return []
        if op.length is 0
          return [ __('All plugins are up to date.') ]
        else
          return (
            for p in op
              __('Found update for %s: current version is %s, latest version is: %s', 
                p.plugin, p.current, p.latest
              )
          ) 
      )

    installUpdatesClicked: ->
      modules = (if @pimaticUpdateInfo().isOutdated then ['pimatic'] else [])
      modules = modules.concat (p.plugin for p in @outdatedPlugins())

      $.ajax(
        url: "/api/update"
        type: 'POST'
        data: {
          modules: modules
        }
        global: false
        timeout: 10000000 #ms
      ).fail( (jqXHR, textStatus, errorThrown) =>
        # ignore timeouts:
        if textStatus isnt "timeout"
          ajaxAlertFail(jqXHR, textStatus, errorThrown)
      )

    restart: ->
      $.get('/api/restart').fail(ajaxAlertFail)

    searchForPimaticUpdate: ->
      return $.ajax(
        url: "/api/outdated/pimatic"
        timeout: 300000 #ms
      ).done( (data) =>
        @pimaticUpdateInfo(data)
        return 
      ).fail(ajaxAlertFail)

    searchForOutdatedPlugins: ->
      return $.ajax(
        url: "/api/outdated/plugins"
        timeout: 300000 #ms
      ).done( (data) =>
        @outdatedPlugins(data.outdated)
        return
      ).fail(ajaxAlertFail)

  try
    pimatic.pages.updates = updatePage = new UpdateViewModel()
    ko.applyBindings(updatePage, $('#updates')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on "pageshow", '#updates', (event) ->
  try
    updatesPage = pimatic.pages.updates
    updatesPage.searchForPimaticUpdate()
    updatesPage.searchForOutdatedPlugins()
  catch e
    TraceKit.report(e)