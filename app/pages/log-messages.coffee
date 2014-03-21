# log-page
# ---------

$(document).on("pageinit", '#log', (event) ->

  class LogMessageViewModel

    @mapping = {
      message:
        key: (data) => data.time + data.message
    }

    messages: ko.observableArray([])

    constructor: ->
      @listViewRequest = ko.computed( =>
        @messages()
        $('#log-messages').listview('refresh') 
      ).extend(rateLimit: {timeout: 0, method: "notifyWhenChangesStop"})

    updateFromJs: (data) ->
      ko.mapping.fromJS(data, LogMessageViewModel.mapping, this)

  pimatic.pages.log = logPage = new LogMessageViewModel()

  $.get("/api/messages")
    .done( (data) ->
      if data.success
        logPage.updateFromJs(data)
    ).fail(ajaxAlertFail)

  pimatic.socket.on 'log', (entry) -> 
    logPages.message.push entry

  $('#log').on "click", '#clear-log', (event, ui) ->
    $.get("/clear-log")
      .done( ->
        logPage.messages.removeAll()
        pimatic.pages.index.errorCount(0)
      ).fail(ajaxAlertFail)

  ko.applyBindings(logPage, $('#log')[0])
  return
)

 # =
 #  lastEntry: null
 #  addLogMessage: (entry) ->
 #    li = $ $('#log-message-template').html()
 #    li.find('.level').text(entry.level).addClass(entry.level)
 #    li.find('.msg').text(entry.msg)
 #    lastDate = pimatic.pages.log.lastEntry?.time.substring(0, 10)
 #    newDate = entry.time.substring(0, 10)
 #    li.find('.time').text(
 #      (if lastDate isnt newDate then entry.time else entry.time.substring 11, 19) + " "
 #    )
 #    pimatic.pages.log.lastEntry = entry
 #    $('#log-messages').append li
 #    return