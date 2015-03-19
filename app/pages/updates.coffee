# updates-page
# ---------


# log-page
# ---------

$(document).on("pagecreate", '#updates-page', (event) ->

  class UpdateViewModel

    pimaticUpdateInfo: ko.observable(null)
    outdatedPlugins: ko.observableArray(null)

    constructor: ->
      @updateProcessStatus = pimatic.updateProcessStatus
      @updateProcessMessages = pimatic.updateProcessMessages

      @hasUpdates = ko.computed( =>
        return (@pimaticUpdateInfo()?.outdated) or (@outdatedPlugins().length > 0)
      )

      @pimaticUpdateInfoText = ko.computed( =>
        info = @pimaticUpdateInfo()
        unless info? then return ''
        if info.outdated
          return __('Found update for %s: current version is %s, latest version is: %s', 
            'pimatic', 
            info.outdated.current, 
            info.outdated.latest
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
      modules = (if @pimaticUpdateInfo().outdated then ['pimatic'] else [])
      modules = modules.concat (p.plugin for p in @outdatedPlugins())

      pimatic.client.rest.installUpdatesAsync({modules})
      .fail( (jqXHR, textStatus, errorThrown) =>
        # ignore timeouts:
        if textStatus isnt "timeout"
          ajaxAlertFail(jqXHR, textStatus, errorThrown)
      )

    restart: ->
      pimatic.client.rest.restart({}).fail(ajaxAlertFail)

    searchForPimaticUpdate: ->
      return pimatic.client.rest.isPimaticOutdated().done( (data) =>
        @pimaticUpdateInfo(data)
        return 
      ).fail(ajaxAlertFail)

    searchForOutdatedPlugins: ->
      return pimatic.client.rest.getOutdatedPlugins().done( (data) =>
        @outdatedPlugins(data.outdatedPlugins)
        return
      ).fail(ajaxAlertFail)

  try
    pimatic.pages.updates = updatePage = new UpdateViewModel()
    ko.applyBindings(updatePage, $('#updates-page')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on "pageshow", '#updates-page', (event) ->
  try
    updatesPage = pimatic.pages.updates
    updatesPage.searchForPimaticUpdate()
    updatesPage.searchForOutdatedPlugins()
  catch e
    TraceKit.report(e)