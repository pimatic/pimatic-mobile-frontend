
  # device = null
  # chartInfo = null
  # sensorListener = null

tc = pimatic.tryCatch

$(document).on "pagecreate", '#index', (event) ->

  $('#index').on "click", '#item-lists li.item .attributes.contains-attr-type-number', ->
    device = ko.dataFor($(this).parent('.item')[0])?.device
    jQuery.mobile.pageParams = {
      device: device
    }
    jQuery.mobile.changePage '#graph-page', transition: 'slide'

$(document).on "pagecreate", '#graph-page', (event) ->

  Highcharts.setOptions(
    global:
      useUTC: false
  )

  class TaskQuery
    query: []
    addTask: (task, prepend = false) ->
      task.onComplete = ( => 
        task.status = 'complete'
        @next()
      )
      if prepend
        @query.unshift task
      else
        @query.push task
      @start()
    start: ->
      if @query.length is 0 then return
      first = @query[0]
      if first.status is "running" then return
      first.status = "running"
      first.start()
    next: ->
      @query = (t for t in @query when t.status isnt "complete")
      @start()
    clear: ->
      for t in @query
        if t.abort? then t.abort()
        t.status = "aborted"
      @query.length = 0

  class GraphPageViewModel

    groups: pimatic.groups
    displayedAttributes: ko.observableArray()
    dateFrom: ko.observable()
    dateTo: ko.observable()
    chosenRange: ko.observable('day')
    chosenDate: ko.observable()
    pageCreated: ko.observable(false)
    dataLoadingQuery: new TaskQuery()
    averageDuration: ko.observable(null)
    dateFormat: "yy-mm-dd"

    constructor: ->

      # $("#chart-select-date").date('onSelect', -> 
      #   console.log "change"
      # )

      ko.computed( tc =>
        unless @pageCreated() then return false
        g.devices() for g in pimatic.groups()
        pimatic.try( => 
          $('#graph-device-list').listview('refresh')
        )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @averageDurationText = ko.computed( tc =>
        return __("Average values of %s.", @averageDuration()) 
      )

      @chosenDate($.datepicker.formatDate(@dateFormat, new Date()))

      ko.computed( tc =>
        displayed = @displayedAttributes()
        $("#chart").highcharts()?.destroy()
        if displayed.length is 0
          $("#chart").hide()
          return

        @dataLoadingQuery.clear()

        range = @chosenRange()
        chosenDate = @chosenDate()
        unless $.datepicker.parseDate(@dateFormat, chosenDate)?
          return
        groupByTime = @getGroupByTimeForRange(range)
        @averageDuration(@timeDurationToText(groupByTime))

        units = []
        for item in displayed
          item.added = no
          if item.range? and (item.range isnt range or item.chosenDate isnt chosenDate)
            item.range = null
            item.data = null
          unless item.attribute.unit in units
            units.push item.attribute.unit
        yAxis = (
          for unit in units
            {
              labels:
                format: "{value} #{unit}"
              unit: unit
              tooltip:
                valueDecimals: 2
                valueSuffix: " " + unit
              opposite: no
            }
        )

        {to, from} = @getDateRange()

        chartOptions = {
          tooltip:
            valueDecimals: 2
          yAxis: yAxis
          xAxis:
            type: 'datetime'
            dateTimeLabelFormats:
              millisecond: '%H:%M:%S',
              second: '%H:%M:%S',
              minute: '%H:%M',
              hour: '%H:%M',
              day: '%e. %b',
              week: '%e. %b',
              month: '%b \'%y',
              year: '%Y'
            tickPixelInterval: 40
            labels : { y : 20, rotation: -30, align: 'right' }
          rangeSelector:
            enabled: no
          credits:
            enabled: false
          legend:
            enabled: yes
            borderWidth: 1
            borderRadius: 3
          series: []
        }

        chart = $("#chart").highcharts("StockChart", chartOptions)
        chart.show()
        chart = chart.highcharts()
        xAxis = chart.xAxis[0]
        # setTimeout( (=>
        #   pimatic.try -> chart.reflow()
        # ), 500)


        buildSeries = ( (item, data) =>
          y = ko.utils.arrayIndexOf(units, item.attribute.unit)
          return {
            id: "serie-#{item.device.id}-#{item.attribute.name}"
            name: "#{item.device.name()}: #{item.attribute.label}"
            data: data
            yAxis: y
            tooltip:
              valueDecimals: 2
              valueSuffix: " " + item.attribute.unit     
          }
        )

        limit = 100
        loadData = ( (item, fromTime, tillTime, onData, onError, prepend = no) =>
          task = {
            attributeName: item.attribute.name
            abort: onError
          }
          task.start = =>
            startTime = new Date().getTime()
            pimatic.client.rest.querySingleDeviceAttributeEvents({
              deviceId: item.device.id
              attributeName: item.attribute.name
              criteria: {
                after: fromTime
                before: tillTime
                limit: limit
                groupByTime: groupByTime
              }
            }, {global: no}).done( (result) =>
              if task.status is "aborted" then return
              if result.success
                eventsLength = result.events.length
                hasMore = (eventsLength is limit)
                if eventsLength > 0
                  timeDiff = new Date().getTime() - startTime
                  # time diff should not be 0
                  timeDiff = Math.max(timeDiff, 1)
                  # get limit so, that the next request take about 3 seconds
                  limit = Math.floor(eventsLength * (3000 / timeDiff))
                  # Limit should be at least 100
                  limit = Math.max(limit, 100)
                  if hasMore
                    last = result.events[eventsLength-1]
                    loadData(item, last.time+1, tillTime, onData, onError, yes)
                  onData(result.events, hasMore)
                else
                  onData(result.events, false)
            ).always( ->
              if task.status is "aborted" then return
              task.onComplete()
            ).fail( ->
              onError()
            )

          @dataLoadingQuery.addTask(task, prepend)
        )

        addSeriesToChart = ( (item, data) =>
          pimatic.try -> chart.reflow()
          serieConf = buildSeries(item, data)
          serie = chart.addSeries(serieConf, redraw=yes, animate=no)
          item.added = yes
          item.chosenDate = chosenDate
          item.range = range
          item.serie({
            id: serieConf.id
            index: serie.index
            color: serie.color
          })
        )


        addSeries = ( (item) =>
          if item.data?
            addSeriesToChart(item, item.data)
          else
            allData = []
            loadingId = "loading-series-" + item.device.id + "_" + item.attribute.name
            pimatic.loading(loadingId, "show", {
              text: __("Loading data for #{item.device.name()}: #{item.attribute.label}")
              blocking: no
            })
            item.data = null
            loadData(item, from.getTime(), to.getTime(), onData = ( (events, hasMore) =>
              data = ([time, value] for {time, value} in events)
              unless item.added
                addSeriesToChart(item, data)
              else
                #t = new Date().getTime()
                serie = chart.get(item.serie().id)
                for d in data
                  serie.addPoint(d, no)
                #console.log "insert:", (new Date().getTime() - t)
              #t = new Date().getTime()
              xAxis.setExtremes(from.getTime(), to.getTime())
              #console.log "setExtremes:", (new Date().getTime() - t)
              allData = allData.concat data
              unless hasMore
                item.data = allData
                item.range = range
                #t = new Date().getTime()
                chart.redraw()
                #console.log "redraw:", (new Date().getTime() - t)
                pimatic.loading(loadingId, "hide")
            ), onError = => pimatic.loading(loadingId, "hide") )
        )

        addSeries(item) for item in displayed

      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

    getUngroupedDevicesWithNumericAttribute: () ->
      ungrouped = pimatic.getUngroupedDevices()
      return (d for d in ungrouped when d.hasAttibuteWith( (attr) => attr.type is "number" ))

    afterRenderAttribute: (elements) =>
      sliderEle = $(elements).find('select')
      pimatic.try => sliderEle.flipswitch()


    getDisplayedAttribute:  (device, attribute) ->
      for item in @displayedAttributes()
        if item.device is device and item.attribute is attribute
          return item
      return null

    addToDisplayedAttributes: (device, attribute) ->
      if @getDisplayedAttribute(device, attribute)? then return
      @displayedAttributes.push {device, attribute, serie: ko.observable()}

    removeFromDisplayedAttributes: (device, attribute) ->
      @displayedAttributes.remove( (item) => 
        item.device is device and item.attribute is attribute 
      )

    isLive: () ->
      now = new Date()
      chosenDate = $.datepicker.parseDate(@dateFormat, @chosenDate())
      if chosenDate is null then return false
      return (
        (chosenDate.getFullYear() is now.getFullYear()) and 
        (chosenDate.getMonth() is now.getMonth()) and 
        (chosenDate.getDate() is now.getDate())
      )

    getDateRange: () ->
      range = @chosenRange()
      chosenDate = $.datepicker.parseDate(@dateFormat, @chosenDate())
      unless @isLive()
        to = new Date(chosenDate)
        to.setDate(to.getDate()+1)
      else
        to = new Date()
      from = new Date(to)
      switch range
        when "day" then from.setDate(to.getDate()-1)
        when "week" then from.setDate(to.getDate()-7)
        when "month" then from.setDate(to.getDate()-30)
        when "year" then from.setDate(to.getDate()-365)
      return {from, to}

    getGroupByTimeForRange: (range) ->
      time =(
        switch range
          when "day" then 5*60*1000 #=5min
          when "week" then 30*60*1000 #=30min
          when "month" then 2*60*60*1000 #=2h
          when "year" then 4*60*60*1000 #=4h
      )
      return time

    timeDurationToText: (time) ->
      #skip ms
      time = time / 1000
      text = ''
      m = time/60
      s = time%60
      if s isnt 0
        text = "#{s}s #{text}"
      if m isnt 0
        if m < 60
          text = "#{m}min #{text}" if m isnt 0
        else
          h = m/60
          m = m%60
          if m isnt 0
            text = "#{h}h #{m}min #{text}"
          else
            text = "#{h}h #{text}"
      return text.trim()

  pimatic.pages.graph = graphPage = new GraphPageViewModel()

  ko.applyBindings(graphPage, $('#graph-page')[0])
  graphPage.pageCreated(yes)

  $('#graph-page').on("click", ".device-attribute-list .show-button", tc (event) ->
    attribute = ko.dataFor(this)
    device = ko.dataFor($(this).parents('.graph-device')[0])
    graphPage.addToDisplayedAttributes(device, attribute)
    return
  )
  
  $('#graph-page').on("click", ".device-attribute-list .hide-button", tc (event) ->
    attribute = ko.dataFor(this)
    device = ko.dataFor($(this).parents('.graph-device')[0])
    graphPage.removeFromDisplayedAttributes(device, attribute)
    return
  )

$(document).on("pagebeforeshow", '#graph-page', (event) ->
  page = pimatic.pages.graph
  device = jQuery.mobile.pageParams?.device
  jQuery.mobile.pageParams = {}
  if device?
    toDisplay = []
    for attr in device.attributes()
      if attr.type is "number"
        toDisplay.push {device, attribute: attr, serie: ko.observable()}
  page.displayedAttributes(toDisplay)

)


sensorListener = null

$(document).on "pagehide", '#graph-page', (event) ->
  pimatic.pages.graph.dataLoadingQuery.clear()
  if sensorListener?
    pimatic.socket.removeListener 'deviceAttributeChanged', sensorListener
  return

$(document).on "pagebeforeshow", '#graph-page', () ->
  page = pimatic.pages.graph
  pimatic.socket.on 'deviceAttributeChanged', sensorListener = (attrEvent) ->
    unless page.isLive() then return
    for item in page.displayedAttributes()
      if item.device.id is attrEvent.deviceId and item.attribute.name is attrEvent.attributeName
        if item.serie? and item.data?
          serie = $("#chart").highcharts().get(item.serie().id)
          point = [new Date(attrEvent.time).getTime(), attrEvent.value]
          shift = no
          firstPoint = null
          if serie.options.data.length > 0
            firstPoint = serie.options.data[0]
          if firstPoint?
            {from, to} = page.getDateRange()
            if firstPoint[0] < from.getTime()
              shift = yes
          serie.addPoint(point, redraw=yes, shift, animate=yes)
          pimatic.showToast __('%s: %s value: %s',
            item.device.name(),
            item.attribute.label,
            item.attribute.formatValue(attrEvent.value)
          )
    return



  # updateChartInfo = () ->
  #   chart = $("#chart").highcharts()
  #   data = chart.series[0].options.data
  #   lastPoint = null
  #   if data.length > 0 then lastPoint = data[data.length-1]
  #   if lastPoint?
  #     $('.last-update-time').text(Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', lastPoint[0])) 
  #     $('.last-update-value').text(Highcharts.numberFormat(lastPoint[1], 2) + " " + chartInfo.unit)
  #     $('#chart-info').show()
  #   else
  #     $('#chart-info').hide()