# log-page
# ---------

$(document).on("pageinit", '#log', (event) ->

  class LogMessageViewModel

    @mapping = {
      messages:
        create: ({data, parent, skip}) => data
      ignore: ['success']
    }

    messages: ko.observableArray([])

    constructor: ->
      @listViewRequest = ko.computed( =>
        @messages()
        $('#log-messages').listview('refresh') 
      ).extend(rateLimit: {timeout: 0, method: "notifyWhenChangesStop"})

    updateFromJs: (data) ->
      ko.mapping.fromJS(data, LogMessageViewModel.mapping, this)

    timeToShow: (index) ->
      justDate = (time) -> time.substring(0, 10)
      justTime = (time) -> time.substring(11, 19) 

      index = index()
      messages = @messages()
      #console.log index, messages
      if index is 0 then return messages[index].time
      else 
        before = justDate(messages[index-1].time)
        current = justDate(messages[index].time)
        if current is before then return justTime(messages[index].time)
        else return item.time
    

  pimatic.pages.log = logPage = new LogMessageViewModel()

  $.get("/api/messages")
    .done( (data) ->
      if data.success
        logPage.updateFromJs(data)
    ).fail(ajaxAlertFail)

  pimatic.socket.on 'log', (entry) -> 
    logPage.messages.push entry

  $('#log').on "click", '#clear-log', (event, ui) ->
    $.get("/clear-log")
      .done( ->
        logPage.messages.removeAll()
        pimatic.pages.index.errorCount(0)
      ).fail(ajaxAlertFail)

  ko.applyBindings(logPage, $('#log')[0])
  return
)