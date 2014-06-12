# log-page
# ---------
tc = pimatic.tryCatch
$(document).on("pagecreate", '#events', tc (event) ->


  class DeviceAttributeEvent

    constructor: (@data) ->
      @device = ko.computed( => 
        pimatic.getDeviceById(data.deviceId) 
      ).extend(rateLimit: {timeout: 10, method: "notifyAtFixedRate"})
      @attribute = ko.computed( =>
        if @device()? then @device().getAttribute(data.attributeName)
        else null
      )

    formatedTime: () ->
      pad = (n) => if n < 10 then "0#{n}" else "#{n}"
      d = new Date(@data.time)
      date = pad(d.getDate()) + '.' + pad((d.getMonth()+1)) + '.' + d.getFullYear()
      time = pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds())
      return """
        <span class="date">#{date}</span> 
        <span class="time">#{time}</span>
      """

    formatedValue: () ->
      if @attribute()? then return @attribute().formatValue(@data.value)
      return @data.value

    formatedDeviceName: () ->
      if @device()? then return """
        <span class="device-name">#{@device().name()}</span> 
        <span class="device-id">(#{@data.deviceId})</span>
      """
      return @data.deviceId

    formatedAttributeName: () ->
      if @attribute()? then return @attribute().label
      return @data.attributeName



  class EventViewModel

    @mapping = {
      events:
        create: ({data, parent, skip}) => new DeviceAttributeEvent(data)
        key: (data) -> "#{data.time}-#{data.deviceId}-#{data.attributeName}" 
      ignore: ['success']
    }

    devices: ko.observableArray(['All'])
    chosenDevice: ko.observable()
    attributes: ko.observableArray(['All'])
    chosenAttribute: ko.observable()

    constructor: ->
      @updateFromJs([])
      @displayedEvents = ko.computed( =>
        events = @events()
        chosenDevice = @chosenDevice()
        chosenAttribute = @chosenAttribute()
        displayed = (
          e for e in events when (
            (chosenDevice is 'All' or chosenDevice is e.data.deviceId) and
            (chosenAttribute is 'All' or chosenAttribute is e.data.attributeName)
          )
        )
        return displayed
      ).extend(rateLimit: {timeout: 10, method: "notifyAtFixedRate"})

      ko.computed( =>
        @loadEvents()
      )

      @updateListView = ko.computed( =>
        @displayedEvents()
        pimatic.try => $('#events-table').table("refresh") 
      ).extend(rateLimit: {timeout: 10, method: "notifyAtFixedRate"})

    updateFromJs: (data) ->
      ko.mapping.fromJS({events: data}, EventViewModel.mapping, this)

    loadEvents: ->

      ajaxCall = =>
        if @loadEventsAjax? then return
        pimatic.loading "loading events", "show", text: __('Loading Events')
        
        criteria = {
          limit: 100
        }

        pimatic.client.rest.queryDeviceAttributeEvents( { criteria }).always( ->
          pimatic.loading "loading events", "hide"
        ).done( tc (data) =>
          @loadEventsAjax = null
          if data.success
            for item in data.events
              unless item.deviceId in @devices()
                @devices.push item.deviceId
              unless item.attributeName in @attributes()
                @attributes.push item.attributeName
            @updateFromJs(data.events)
          return
        ).fail(ajaxAlertFail)

      unless @loadEventsAjax? then ajaxCall()
      else @loadEventsAjax.done( => ajaxCall() )


    # loadMessagesMeta: ->
    #   $.ajax("/api/database/queryMessagesTags",
    #     global: false # don't show loading indicator
    #   ).done( tc (data) =>
    #     if data.success
    #       for t in data.tags
    #         unless t in @tags() then @tags.push t
    #   )
    #   $.ajax("/api/database/queryMessagesCount",
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
