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
    }

    constructor: ->
      @hasPermission = pimatic.hasPermission
      @updateFromJs([])

      @updateListView = ko.computed( =>
        @problems()
        pimatic.try => $('#log-messages').listview('refresh') 
      )

    updateFromJs: (data) ->
      ko.mapper.fromJS({problems: data}, DatabaseViewModel.mapping, this)

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
            @updateFromJs(data.problems)
          return
        ).fail(ajaxAlertFail)

      unless @loadProblemsAjax? then ajaxCall()
      else @loadProblemsAjax.done( => ajaxCall() )

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
    databasePage.checkDatabase();
  catch e
    TraceKit.report(e)
)
