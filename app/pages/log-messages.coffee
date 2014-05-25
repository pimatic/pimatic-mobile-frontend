# log-page
# ---------
tc = pimatic.tryCatch
$(document).on("pagecreate", '#log', tc (event) ->

  class LogMessageViewModel

    @mapping = {
      messages:
        create: ({data, parent, skip}) => data
        key: (data) -> data.id
      ignore: ['success']
    }
    chosenLevels: ko.observableArray([])
    tags: ko.observableArray(['All', 'pimatic'])
    chosenTag: ko.observableArray([])

    constructor: ->
      ko.mapping.fromJS({messages: []}, LogMessageViewModel.mapping, this)
      @displayedMessages = ko.computed( =>
        chosenLevels = @chosenLevels()
        chosenTag = @chosenTag()
        messages = @messages()

        displayed = (
          m for m in messages when (
            m.level in chosenLevels and (chosenTag is 'All' or chosenTag in m.tags)
          )
        )
        console.log displayed
        return displayed
      ).extend(rateLimit: {timeout: 10, method: "notifyAtFixedRate"})

      @updateListView = ko.computed( =>
        @displayedMessages()
        $('#log-messages').listview('refresh') 
      )
    updateFromJs: (data) ->
      ko.mapping.fromJS({messages: data}, this)

    timestampToDateTime: (time) ->
      pad = (n) => if n < 10 then "0#{n}" else "#{n}"
      d = new Date(time)
      date = pad(d.getDate()) + '.' + pad((d.getMonth()+1)) + '.' + d.getFullYear()
      time = pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds())
      return {date, time}

    timeToShow: (index) ->
      index = index()
      messages = @messages()
      #console.log index, messages
      if index is 0 
        msg = messages[index]
        unless msg? then return ''
        dt = @timestampToDateTime(msg?.time)
        return "#{dt.date} #{dt.time}"
      else 
        [msgBefore, msgCurrent] = [ messages[index-1], messages[index] ]
        [before, current] = [ @timestampToDateTime(msgBefore.time), @timestampToDateTime(msgCurrent.time) ]
        if current.date is before.date then return current.time
        else return "#{current.date} #{current.time}"

    loadMessages: ->
      pimatic.loading "loading message", "show", text: __('Loading Messages')
      $.ajax("/api/eventlog/queryMessages",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "loading message", "hide"
      ).done( tc (data) ->
        if data.success
          console.log data.result
          logPage.updateFromJs({messages: data.result})
      ).fail(ajaxAlertFail)
    
  try
    pimatic.pages.log = logPage = new LogMessageViewModel()

    pimatic.socket.on 'log', tc (entry) -> 
      logPage.messages.push entry

    $('#log').on "click", '#clear-log', tc (event, ui) ->
      lastMessage = logPage.messages[logPage.messages.length-1]
      $.ajax("/api/messages/delete",
        data: {beforeTime: lastMessage.time}
      ).done( tc ->
        logPage.messages.removeAll()
        pimatic.pages.index.errorCount(0)
      ).fail(ajaxAlertFail)

    ko.applyBindings(logPage, $('#log')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#log', tc (event) ->
  try
    pimatic.pages.log.loadMessages()
  catch e
    TraceKit.report(e)
)
