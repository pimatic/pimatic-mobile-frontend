# log-page
# ---------
tc = pimatic.tryCatch
$(document).on("pagecreate", '#events', tc (event) ->

  class EventViewModel

    @mapping = {
      events:
        create: ({data, parent, skip}) => data
        key: (data) -> "#{data.time}-#{data.deviceId}-#{data.attributeName}" 
      ignore: ['success']
    }

    constructor: ->
      @updateFromJs([])
      @displayedEvents = ko.computed( =>
        events = @events()
        displayed = (
          e for e in events when (
            true # m.level in chosenLevels and (chosenTag is 'All' or chosenTag in m.tags)
          )
        )
        return displayed
      ).extend(rateLimit: {timeout: 10, method: "notifyAtFixedRate"})

      ko.computed( =>
        @loadEvents()
      )

      # @messageCountText = ko.computed( =>
      #   count = @messageCount()
      #   return (
      #     if count? then __("Showing %s of %s Messages", @displayedMessages().length, count)
      #     else ""
      #   )
      # )

      @updateListView = ko.computed( =>
        @displayedEvents()
        $('#events-table').table("refresh") 
      )
    updateFromJs: (data) ->
      ko.mapping.fromJS({events: data}, EventViewModel.mapping, this)

    loadEvents: ->

      ajaxCall = =>
        if @loadEventsAjax? then return
        pimatic.loading "loading events", "show", text: __('Loading Events')
        
        criteria = {
          limit: 100
        }

        @loadEventsAjax = $.ajax("/api/eventlog/queryDeviceAttributeEvents",
          global: false # don't show loading indicator
          data: { criteria }
        ).always( ->
          pimatic.loading "loading events", "hide"
        ).done( tc (data) =>
          @loadEventsAjax = null
          if data.success
            @updateFromJs(data.events)
          return
        ).fail(ajaxAlertFail)

      unless @loadEventsAjax? then ajaxCall()
      else @loadEventsAjax.done( => ajaxCall() )

    formatTime: (time) ->
      pad = (n) => if n < 10 then "0#{n}" else "#{n}"
      d = new Date(time)
      date = pad(d.getDate()) + '.' + pad((d.getMonth()+1)) + '.' + d.getFullYear()
      time = pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds())
      return "#{date} #{time}"

    # loadMessagesMeta: ->
    #   $.ajax("/api/eventlog/queryMessagesTags",
    #     global: false # don't show loading indicator
    #   ).done( tc (data) =>
    #     if data.success
    #       for t in data.tags
    #         unless t in @tags() then @tags.push t
    #   )
    #   $.ajax("/api/eventlog/queryMessagesCount",
    #     global: false # don't show loading indicator
    #   ).done( tc (data) =>
    #     if data.success
    #       @messageCount(data.count)
    #   )

    
  try
    pimatic.pages.events = eventsPage = new EventViewModel()
    ko.applyBindings(eventsPage, $('#events')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#events', tc (event) ->
  try
    pimatic.pages.events.loadEvents()
  catch e
    TraceKit.report(e)
)
