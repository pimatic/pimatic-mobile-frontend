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
    chosenLevels: ko.observableArray(['info', 'warn', 'error'])
    tags: ko.observableArray(['All', 'pimatic'])
    chosenTag: ko.observableArray([])
    messageCount: ko.observable(null)

    constructor: ->
      @updateFromJs([])
      @displayedMessages = ko.computed( =>
        chosenLevels = @chosenLevels()
        chosenTag = @chosenTag()
        messages = @messages()

        displayed = (
          m for m in messages when (
            m.level in chosenLevels and (chosenTag is 'All' or chosenTag in m.tags)
          )
        )

        return displayed
      ).extend(rateLimit: {timeout: 10, method: "notifyAtFixedRate"})

      ko.computed( =>
        @chosenLevels()
        @chosenTag()
        @loadMessages()
      )

      @messageCountText = ko.computed( =>
        count = @messageCount()
        return (
          if count? then __("Showing %s Messages of %s", @displayedMessages().length, count)
          else ""
        )
      )

      @updateListView = ko.computed( =>
        @displayedMessages()
        $('#log-messages').listview('refresh') 
      )
    updateFromJs: (data) ->
      ko.mapping.fromJS({messages: data}, LogMessageViewModel.mapping, this)

    timestampToDateTime: (time) ->
      pad = (n) => if n < 10 then "0#{n}" else "#{n}"
      d = new Date(time)
      date = pad(d.getDate()) + '.' + pad((d.getMonth()+1)) + '.' + d.getFullYear()
      time = pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds())
      return {date, time}

    timeToShow: (index) ->
      index = index()
      dMessages = @displayedMessages()
      if index is 0 
        msg = dMessages[index]
        unless msg? then return ''
        dt = @timestampToDateTime(msg?.time)
        return "#{dt.date} #{dt.time}"
      else 
        [msgBefore, msgCurrent] = [ dMessages[index-1], dMessages[index] ]
        [before, current] = [ @timestampToDateTime(msgBefore.time), @timestampToDateTime(msgCurrent.time) ]
        if current.date is before.date then return current.time
        else return "#{current.date} #{current.time}"

    loadMessages: ->
      pimatic.loading "loading message", "show", text: __('Loading Messages')

      ajaxCall = =>
        if @loadMessagesAjax? then return
        
        criteria = {
          level: @chosenLevels()
          limit: 100
        }
        criteria.tags = @chosenTag() if @chosenTag() isnt 'All'

        @loadMessagesAjax = $.ajax("/api/eventlog/queryMessages",
          global: false # don't show loading indicator
          data: { criteria }
        ).always( ->
          pimatic.loading "loading message", "hide"
        ).done( tc (data) =>
          @loadMessagesAjax = null
          if data.success
            logPage.updateFromJs(data.messages)
            for m in data.messages 
              for t in m.tags
                unless t in @tags() then @tags.push t
          return
        ).fail(ajaxAlertFail)

      unless @loadMessagesAjax? then ajaxCall()
      else @loadMessagesAjax.done( => ajaxCall() )

    loadMessagesMeta: ->
      $.ajax("/api/eventlog/queryMessagesTags",
        global: false # don't show loading indicator
      ).done( tc (data) =>
        if data.success
          for t in data.tags
            unless t in @tags() then @tags.push t
      )
      $.ajax("/api/eventlog/queryMessagesCount",
        global: false # don't show loading indicator
      ).done( tc (data) =>
        if data.success
          @messageCount(data.count)
      )

    
  try
    pimatic.pages.log = logPage = new LogMessageViewModel()

    pimatic.socket.on 'log', tc (entry) -> 
      count = logPage.messageCount()
      if count? then logPage.messageCount(count+1)
      logPage.messages.unshift entry

    $('#log').on "click", '#clear-log', tc (event, ui) ->
      lastMessage = logPage.messages[logPage.messages.length-1]
      $.ajax("/api/eventlog/deleteMessages"
      ).done( tc ->
        logPage.messages.removeAll()
        pimatic.pages.index.errorCount(0)
        logPage.messageCount(0)
      ).fail(ajaxAlertFail)

    ko.applyBindings(logPage, $('#log')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#log', tc (event) ->
  try
    pimatic.pages.log.loadMessages()
    pimatic.pages.log.loadMessagesMeta()
  catch e
    TraceKit.report(e)
)
