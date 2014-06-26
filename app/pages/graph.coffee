
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

  class GraphPageViewModel

    groups: pimatic.groups
    displayedAttributes: ko.observableArray()
    dateFrom: ko.observable()
    dateTo: ko.observable()
    chosenRange: ko.observable('day')
    pageCreated: ko.observable(false)

    constructor: ->
      ko.computed( tc =>
        unless @pageCreated() then return false
        g.devices() for g in pimatic.groups()
        pimatic.try( => 
          $('#graph-device-list').listview('refresh')
        )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      ko.computed( tc =>
        displayed = @displayedAttributes()
        $("#chart").highcharts()?.destroy()
        if displayed.length is 0
          $("#chart").hide()
          return
        range = @chosenRange()
        units = []
        for item in displayed
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
          rangeSelector:
            enabled: no
          credits:
            enabled: false
          series: []
        }

        chart = $("#chart").highcharts("StockChart", chartOptions)
        chart.show()
        chart = chart.highcharts()
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

        loadData = ( (item) =>
          return pimatic.client.rest.querySingleDeviceAttributeEvents({
            deviceId: item.device.id
            attributeName: item.attribute.name
            criteria: {
              after: from.getTime()
              before: to.getTime()
            }
          })
        )

        addSeriesToChart = ( (item, data) =>
          pimatic.try -> chart.reflow()
          serieConf = buildSeries(item, data)
          serie = chart.addSeries(serieConf)
          item.data = data
          item.range = range
          item.serie({
            id: serieConf.id
            index: serie.index
            color: serie.color
          })
        )


        addSeries = ( (item) =>
          if item.data? and item.range is range
            addSeriesToChart(item, item.data)
          else
            loadData(item).done( (result) =>
              if result.success
                data = ([time, value] for {time, value} in result.events)
                addSeriesToChart(item, data)
            )
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

    getDateRange: () ->
      range = @chosenRange()
      to = new Date
      from = new Date()
      switch range
        when "day" then from.setDate(to.getDate()-1)
        when "week" then from.setDate(to.getDate()-7)
        when "month" then from.setDate(to.getDate()-30)
        when "year" then from.setDate(to.getDate()-365)
      return {from, to}


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
  device = jQuery.mobile.pageParams?.device
  jQuery.mobile.pageParams = {}
  if device?
    for attr in device.attributes()
      if attr.type is "number"
        pimatic.pages.graph.addToDisplayedAttributes(device, attr)

)


sensorListener = null

$(document).on "pagehide", '#graph-page', (event) ->
  if sensorListener?
    pimatic.socket.removeListener 'deviceAttributeChanged', sensorListener
  return

$(document).on "pagebeforeshow", '#graph-page', () ->
  page = pimatic.pages.graph
  pimatic.socket.on 'deviceAttributeChanged', sensorListener = (attrEvent) ->
    for item in page.displayedAttributes()
      if item.device.id is attrEvent.deviceId and item.attribute.name is attrEvent.attributeName
        if item.serie?
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