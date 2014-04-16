# log-page
# ---------

$(document).on("pagecreate", '#log', (event) ->

  class LogMessageViewModel

    @mapping = {
      messages:
        create: ({data, parent, skip}) => data
        key: (data) -> data.id
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
      if index is 0 
        msg = messages[index]
        return msg?.time
      else 
        [msgBefore, msgCurrent] = [ messages[index-1], messages[index] ]
        [before, current] = [ justDate(msgBefore.time), justDate(msgCurrent.time) ]
        if current is before then return justTime(msgCurrent.time)
        else return msgCurrent.time

    loadMessages: ->
      pimatic.loading "loading message", "show", text: __('Loading Messages')
      $.ajax("/api/messages",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "loading message", "hide"
      ).done( (data) ->
        if data.success
          logPage.updateFromJs(data)
      ).fail(ajaxAlertFail)
    

  pimatic.pages.log = logPage = new LogMessageViewModel()

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

$(document).on("pagebeforeshow", '#log', (event) ->
  pimatic.pages.log.loadMessages()
)
