# log-page
# ---------
tc = pimatic.tryCatch
$(document).on("pagecreate", '#log-page', tc (event) ->

  class LogMessageViewModel

    @mapping = {
      $default: 'ignore'
      messages:
        $key: 'id'
        $itemOptions:
          $handler: 'copy'
    }
    chosenLevels: ko.observableArray(['info', 'warn', 'error'])
    tags: ko.observableArray(['All', 'pimatic'])
    chosenTag: ko.observableArray([])
    messageCount: ko.observable(null)

    constructor: ->
      @hasPermission = pimatic.hasPermission
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
          if count? then __("Showing %s of %s Messages", @displayedMessages().length, count)
          else ""
        )
      )

      @updateListView = ko.computed( =>
        @displayedMessages()
        $('#log-messages').listview('refresh') 
      )

      pimatic.socket.on('messageLogged', tc (entry) => 
        @messages.unshift({
          tags: entry.meta.tags
          level: entry.level
          text: entry.msg
          time: entry.meta.timestamp
        })
      )

    updateFromJs: (data) ->
      ko.mapper.fromJS({messages: data}, LogMessageViewModel.mapping, this)



    timeToShow: (index) ->
      index = index()
      dMessages = @displayedMessages()
      if index is 0 
        msg = dMessages[index]
        unless msg? then return ''
        dt = pimatic.timestampToDateTime(msg?.time)
        return "#{dt.date} #{dt.time}"
      else 
        [msgBefore, msgCurrent] = [ dMessages[index-1], dMessages[index] ]
        [before, current] = [ 
          pimatic.timestampToDateTime(msgBefore.time), 
          pimatic.timestampToDateTime(msgCurrent.time) 
        ]
        if current.date is before.date then return current.time
        else return "#{current.date} #{current.time}"

    orderedInsert: (@list, item)->
      pos = -1
      for elem, index in @list
        if elem >= item
          pos = index
          break
      if pos is -1
        @list.push item
      else
        @list.splice index, 0, item

    loadMessages: ->

      ajaxCall = =>
        if @loadMessagesAjax? then return
        pimatic.loading "loading message", "show", text: __('Loading Messages')

        criteria = {
          level: @chosenLevels()
          limit: 100
        }
        criteria.tags = @chosenTag() if @chosenTag() isnt 'All'

        pimatic.client.rest.queryMessages(
          {criteria},
          {timeout: 60000, global: no}
        ).always( =>
          pimatic.loading "loading message", "hide"
        ).done( tc (data) =>
          @loadMessagesAjax = null
          if data.success
            @updateFromJs(data.messages)
            for m in data.messages 
              for t in m.tags
                unless t in @tags() then @orderedInsert @tags, t
          return
        ).fail(ajaxAlertFail)

      unless @loadMessagesAjax? then ajaxCall()
      else @loadMessagesAjax.done( => ajaxCall() )

    loadMessagesMeta: ->
      pimatic.client.rest.queryMessagesTags({criteria: {}}).done( tc (data) =>
        if data.success
          for t in data.tags
            unless t in @tags() then @orderedInsert @tags, t
      )
      pimatic.client.rest.queryMessagesCount({criteria: {}}).done( tc (data) =>
        if data.success
          @messageCount(data.count)
      )

    
  try
    pimatic.pages.log = logPage = new LogMessageViewModel()

    pimatic.socket.on 'log', tc (entry) -> 
      count = logPage.messageCount()
      if count? then logPage.messageCount(count+1)
      logPage.messages.unshift entry

    $('#log-page').on "click", '#clear-log', tc (event, ui) ->
      lastMessage = logPage.messages[logPage.messages.length-1]
      pimatic.client.rest.deleteMessages({criteria: {}}).done( tc ->
        logPage.messages.removeAll()
        pimatic.pages?.index?.errorCount(0)
        logPage.messageCount(0)
      ).fail(ajaxAlertFail)

    ko.applyBindings(logPage, $('#log-page')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#log-page', tc (event) ->
  try
    logPage = pimatic.pages.log

    if jQuery.mobile.pageParams?
      if jQuery.mobile.pageParams.selectErrors
        logPage.chosenLevels(['error'])
      jQuery.mobile.pageParams = null
      
    logPage.loadMessages()
    logPage.loadMessagesMeta()
  catch e
    TraceKit.report(e)
)
