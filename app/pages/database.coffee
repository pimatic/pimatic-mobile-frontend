# log-page
# ---------
tc = pimatic.tryCatch
$(document).on("pagecreate", '#database', tc (event) ->

  class DatabaseViewModel

    @mapping = {
      $default: 'ignore'
      problems:
        $key: 'id'
        $itemOptions:
          $handler: 'copy'
      deviceAttributes:
        $key: 'id'
        $itemOptions:
          $handler: 'copy'
    }

    constructor: ->
      @hasPermission = pimatic.hasPermission
      @updateFromJs(problems: [], deviceAttributes: [])

      @updateListView = ko.computed( =>
        @problems()
        pimatic.try => $('#log-messages').listview('refresh') 
      )

    updateFromJs: (data) ->
      ko.mapper.fromJS(data, DatabaseViewModel.mapping, this)

    deleteDeviceAttribute: (item) =>
      pimatic.client.rest.deleteDeviceAttribute(
        {id: item.id}
      ).done( tc (data) =>
        if data.success
          @problems.remove( (p) -> p.id is item.id )
        return
      ).fail(ajaxAlertFail)

    checkDatabase: ->
      ajaxCall = =>
        if @loadProblemsAjax? then return
        pimatic.loading "databasecheck", "show", text: __('Checking Database')
        pimatic.client.rest.checkDatabase(
          {},
          {timeout: 60000, global: no}
        ).always( =>
          pimatic.loading "databasecheck", "hide"
        ).done( tc (data) =>
          @loadProblemsAjax = null
          if data.success
            @updateFromJs(problems: data.problems)
          return
        ).fail(ajaxAlertFail)

      unless @loadProblemsAjax? then ajaxCall()
      else @loadProblemsAjax.done( => ajaxCall() )

    querydeviceAttributeInfo: ->
      ajaxCall = =>
        if @loadDAInfoAjax? then return
        pimatic.loading "deviceattributeinfo", "show", text: __('Querying attribute info')
        pimatic.client.rest.queryDeviceAttributeEventsInfo(
          {},
          {timeout: 60000, global: no}
        ).always( =>
          pimatic.loading "deviceattributeinfo", "hide"
        ).done( tc (data) =>
          @loadDAInfoAjax = null
          if data.success
            @updateFromJs(deviceAttributes: data.deviceAttributes)
          return
        ).fail(ajaxAlertFail)

      unless @loadDAInfoAjax? then ajaxCall()
      else @loadDAInfoAjax.done( => ajaxCall() )

  try
    pimatic.pages.database = databasePage = new DatabaseViewModel()
    ko.applyBindings(databasePage, $('#database')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#database', tc (event) ->
  try
    databasePage = pimatic.pages.database
    databasePage.checkDatabase()
    databasePage.querydeviceAttributeInfo()
  catch e
    TraceKit.report(e)
)
