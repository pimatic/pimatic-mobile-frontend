
  # device = null
  # chartInfo = null
  # sensorListener = null

tc = pimatic.tryCatch

merge = Array.prototype.concat
LazyLoad.js(merge.apply(scripts.dygraph, scripts.datepicker))

$(document).on("pagecreate", '#graph-page', (event) ->

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
    colors: [
      '#7cb5ec', '#434348', '#90ed7d', '#f7a35c', '#8085e9', 
      '#f15c80', '#e4d354', '#8085e8', '#8d4653', '#91e8e1'
    ]

    constructor: ->
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

      data = pimatic.storage.get('pimatic.graph') or {}
      @collapsedGroups = ko.observable(data.collapsed or {})

      attributeToUnit = (attribute) ->
        return (
          if attribute.type is "boolean" then "__state"
          else attribute.unit
        )

      ko.computed( tc =>
        displayed = @displayedAttributes()
        if displayed.length is 0
          if @chart?
            @chart.destroy()
            @chart = null
          $("#chart").hide()
          $("#chart-info").hide()
          $("#chart-no-data").hide()
          return

        nexStateGraphOffset = 0
        stateGraphOffsets = []

        # sort boolean attributes in displayed to end
        newDisplayed = displayed.filter( 
          (item) -> item.attribute.type is "number"
        )
        newDisplayed = newDisplayed.concat displayed.filter(
          (item) -> item.attribute.type is "boolean"
        )
        displayed = newDisplayed

        @dataLoadingQuery.clear()

        range = @chosenRange()
        chosenDate = @chosenDate()
        unless $.datepicker.parseDate(@dateFormat, chosenDate)?
          return
        groupByTime = @getGroupByTimeForRange(range)
        @averageDuration(@timeDurationToText(groupByTime))

        units = []
        unitsAttributes = []
        for item in displayed
          item.added = no
          if (item.range isnt range or item.chosenDate isnt chosenDate)
            item.range = null
            item.data = null
          unit = attributeToUnit item.attribute
          if item.attribute.type is "boolean"
            stateGraphOffsets[nexStateGraphOffset] = item.attribute
            item.stateOffset = nexStateGraphOffset
            nexStateGraphOffset++
          unless unit in units
            units.push unit
            unitsAttributes[unit]=item.attribute

        yAxis = []

        stateFormater = (value) ->
          # round down
          base = Math.floor(value)
          attribute = stateGraphOffsets[base]
          # 0 => false, 0.5 => 1
          value = (value isnt base) 
          attribute.formatValue(value)
        
        stateTicks = []
        for attribute, base in stateGraphOffsets
          stateTicks.push {v: base, label: attribute.labels[1]}
          stateTicks.push {v: base + 0.5, label: attribute.labels[0]}
        stateTicker = -> stateTicks
        for u in units
          do (u) ->
            unitAttribute = unitsAttributes[u]
            if u is '__state'
              formater = stateFormater
              ticker = stateTicker
            else
              formater = (value) -> unitAttribute.formatValue(value)
              ticker = Dygraph.numericTicks
            yAxis.push(
              axisLabelFormatter: formater
              valueFormatter: formater
              ticker: ticker
            )

        {to, from} = @getDateRange()

        axisName = (i) -> if i is 0 then 'y' else "y#{i+1}"

        chartOptions = {
          labelsDiv: $('#chart-legend')[0]
          legend: 'always'
          tooltip: 'follow'
          staticLegend: true
          strokeWidth: 2
          pointSize: 3
          width: null
          height: null
          labels: [ 'Date' ]
          showRangeSelector: true
          connectSeparatedPoints: true
          rangeSelectorPlotStrokeColor: @colors[0]
          rangeSelectorPlotFillColor: '#e0e6ec'
          xAxisHeight: 35
          highlightSeriesBackgroundAlpha: 0.9
          highlightSeriesOpts: {}
          gridLineColor: '#BDBDBD'
          series: {}
          axes: {
            x: {
              valueFormatter: (date) => 
                dateTime = pimatic.timestampToDateTime(date)
                return "#{dateTime.date} #{dateTime.time}"
              pixelsPerLabel: 25
              axisTickSize: 10
            }
          }
        }

        for yA, i in yAxis
          chartOptions.axes[axisName(i)] = yA

        allChartData = []

        inited = false
        updateChart = =>
          chartDiv = $("#chart")
          noDataInfo = $('#chart-no-data')
          #console.log allChartData, chartOptions
          if allChartData.length > 0
            noDataInfo.hide()
            unless inited 
              @chart.destroy() if @chart?
              chartDiv.show().css('width', '100%')
              chartDiv.parent().css('padding-right', if chartOptions.axes.y2? then 0 else '20px')
              $("#chart-info").show()
              @chart = new Dygraph(chartDiv[0], allChartData, chartOptions)
              inited = true
            else
              updates = {file: allChartData} 
              if chartOptions.axes.x.dateWindow?
                updates.axes = chartOptions.axes
              @chart.updateOptions(updates);
          else
            noDataInfo.show()


        tDelta = 500
        @addChartData = (index, item, data) =>
          #console.log "addChartData", index, data
          allData = allChartData
          newChartData = []
          xRange = @chart?.xAxisRange()
          if xRange? and allChartData.length > 0
            isEnd = xRange[1] is allChartData[allChartData.length-1][0].getTime()
          if item.attribute.type is "boolean" 
            for d in data
              d[1] = if d[1] then item.stateOffset + 0.5 else item.stateOffset
          # merge "sort", alldata with series data
          if data.length is 0
            newChartData = allChartData
          else
            time = data[0][0]
            #console.log "startTime", time
            allDataIndex = 0
            seriesDataIndex = 0
            while seriesDataIndex < data.length
              # keep data before current time
              while allDataIndex < allData.length and allData[allDataIndex][0].getTime() < time - tDelta
                #console.log "keeping", allData[allDataIndex][0].getTime()
                newChartData.push allData[allDataIndex]
                allDataIndex++
              # if there is and point for the time reuse if
              if (
                allDataIndex < allData.length and 
                seriesDataIndex < data.length and 
                Math.abs(data[seriesDataIndex][0] - allData[allDataIndex][0].getTime()) <= tDelta
              )
                #console.log "merging", data[seriesDataIndex][0]
                allData[allDataIndex][index+1] = data[seriesDataIndex][1]
                newChartData.push allData[allDataIndex]
                allDataIndex++
                seriesDataIndex++
                if seriesDataIndex < data.length
                  time = data[seriesDataIndex][0]
              else
                #console.log "inserting", data[seriesDataIndex][0]
                # insert the current time
                d = new Array(displayed.length + 1)
                d[0] = new Date(data[seriesDataIndex][0])
                i = 1
                while i < displayed.length+1
                  d[i] = null
                  i++
                d[index+1] = data[seriesDataIndex][1]
                newChartData.push d
                seriesDataIndex++
                if seriesDataIndex < data.length
                  time = data[seriesDataIndex][0]
            while allDataIndex < allData.length
              #console.log "keeping", allData[allDataIndex][0].getTime()
              newChartData.push allData[allDataIndex]
              allDataIndex++
          allChartData = newChartData
          #console.log allChartData
          if xRange? and isEnd
            xRange[1] = allChartData[allChartData.length-1][0].getTime()
            chartOptions.axes.x.dateWindow = xRange
          updateChart()
          
        loadPreviousData = ( (item, time, onData, onError) =>
          onError = (->) if typeof onError isnt "function"
          task = {
            attributeName: item.attribute.name
            abort: onError
          }
          task.start = ( =>
            pimatic.client.rest.querySingleDeviceAttributeEvents({
              deviceId: item.device.id
              attributeName: item.attribute.name
              criteria: {
                before: time
                limit: 1
                order: 'time'
                orderDirection: 'desc'
              }
            }, {global: no}).done( (result) =>
              if task.status is "aborted" then return
              if result.success
                onData(result.events)
            ).always( ->
              if task.status is "aborted" then return
              task.onComplete()
            ).fail( ->
              onError()
            )
          )
          @dataLoadingQuery.addTask(task, no)
        )


        limit = 100
        loadData = ( (item, fromTime, tillTime, onData, onError, prepend = no) =>
          onError = (->) if typeof onError isnt "function"
          task = {
            attributeName: item.attribute.name
            abort: onError
          }
          task.start = ( =>
            startTime = new Date().getTime()
            pimatic.client.rest.querySingleDeviceAttributeEvents({
              deviceId: item.device.id
              attributeName: item.attribute.name
              criteria: {
                after: fromTime
                before: tillTime
                limit: limit
                groupByTime: groupByTime if (
                  item.attribute.type is "number" and not item.attribute.discrete
                )
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
                  onData(result.events, hasMore)
                  if hasMore
                    last = result.events[eventsLength-1]
                    loadData(item, last.time+1, tillTime, onData, onError, yes)
                else
                  onData(result.events, false)
            ).always( ->
              if task.status is "aborted" then return
              task.onComplete()
            ).fail( ->
              onError()
            )
          )
          @dataLoadingQuery.addTask(task, prepend)
        )

        addSeries = ( (index, item) =>
          y = ko.utils.arrayIndexOf(units, attributeToUnit item.attribute)
          name = "#{item.device.name()}: #{item.attribute.label}"
          orgName = name
          num = 2
          while name in chartOptions.labels
            name = "#{orgName} #{num}"
            num++
          serie = {
            axis: axisName(y)
            stepPlot: item.attribute.discrete
            color: @colors[index % @colors.length]
            showInRangeSelector: (index is 0)
          }
          if item.attribute.type is "boolean"
            serie.strokePattern = Dygraph.DASHED_LINE
            #serie.strokeWidth = 1
          # unless item.attribute.discrete
          #   serie.plotter = smoothPlotter
          item.added = yes
          item.chosenDate = chosenDate
          item.range = range
          item.index = index
          item.serie(serie)
          chartOptions.labels.push name
          chartOptions.series[name] = serie
          updateChart()
          allData = []
          loadingId = "loading-series-" + item.device.id + "_" + item.attribute.name
          pimatic.loading(loadingId, "show", {
            text: __("Loading data for #{item.device.name()}: #{item.attribute.label}")
            blocking: no
          })

          handleData = ( (events) =>
            data = ([time, value] for {time, value} in events)
            @addChartData index, item, data
            allData = allData.concat data
          )

          callLoadData = ( =>
            loadData(item, from.getTime(), to.getTime(), onData = ( (events, hasMore) =>          
              handleData(events)
              unless hasMore
                item.data = allData
                item.range = range
                pimatic.loading(loadingId, "hide")
              return
            ), onError = => pimatic.loading(loadingId, "hide") )
          )

          if item.attribute.discrete
            loadPreviousData(item, from.getTime(), (events) =>
              if events.length is 1
                events[0].time = from.getTime()
              handleData(events)
              callLoadData()
            )
          else
            callLoadData()
        )

        addSeries(index, item) for item, index in displayed

      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})
    
    getUngroupedDevicesWithGraphableAttribute: () ->
      ungrouped = pimatic.getUngroupedDevices()
      return (d for d in ungrouped when d.hasAttibuteWith( 
        (attr) => attr.type in ["boolean", "number"] 
      ))

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


    toggleGroup: (group) =>
      collapsed = @collapsedGroups()
      if collapsed[group.id]
        delete collapsed[group.id]
      else
        collapsed[group.id] = true
      @collapsedGroups(collapsed)
      @saveCollapseState()
      return false

    isGroupCollapsed: (group) => @collapsedGroups()[group.id] is true

    saveCollapseState: () =>
      data = pimatic.storage.get('pimatic.graph') or {}
      data.collapsed = @collapsedGroups()
      pimatic.storage.set('pimatic.graph', data)

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
  return
)

$(document).on("pagebeforeshow", '#graph-page', (event) ->
  page = pimatic.pages.graph
  device = jQuery.mobile.pageParams?.device
  jQuery.mobile.pageParams = {}
  if device?
    toDisplay = []
    for attr in device.attributes()
      if attr.type in ["number", "boolean"]
        toDisplay.push {device, attribute: attr, serie: ko.observable()}
    page.displayedAttributes(toDisplay)
  return
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
        if item.serie? and item.data? and item.added and item.index? and page.addChartData?
          page.addChartData(item.index, item, [[new Date(attrEvent.time).getTime(), attrEvent.value]])
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