
  # device = null
  # chartInfo = null
  # sensorListener = null

tc = pimatic.tryCatch

$(document).on "pagecreate", '#index', (event) ->

  $('#index').on "click", '#item-lists li.item .attributes.contains-attr-type-number', ->
    device = ko.dataFor($(this).parent('.item')[0])?.device
    console.log device
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

        to = new Date
        from = new Date()

        switch range
          when "day" then from.setDate(to.getDate()-1)
          when "week" then from.setDate(to.getDate()-7)
          when "month" then from.setDate(to.getDate()-30)
          when "year" then from.setDate(to.getDate()-365)

        chartOptions = {
          tooltip:
            valueDecimals: 2
          yAxis: yAxis
          rangeSelector:
            enabled: no
          credits:
            enabled: false
          series: []
          chart:
            events:
              load: ->
        }

        chart = $("#chart").highcharts("StockChart", chartOptions)
        chart.show()
        chart = chart.highcharts()
        @_graph_reflow_timeout = setTimeout( (=>
          pimatic.try -> chart.reflow()
        ), 500)

        for item in displayed
          do (item) =>
            pimatic.client.rest.querySingleDeviceAttributeEvents({
              deviceId: item.device.id
              attributeName: item.attribute.name
              criteria: {
                after: from.getTime()
                before: to.getTime()
              }
            }).done( (result) =>
              if result.success
                data = ([time, value] for {time, value} in result.events)
                y = ko.utils.arrayIndexOf(units, item.attribute.unit)
                serie = chart.addSeries(
                  name: "#{item.device.name()}: #{item.attribute.label}"
                  data: data
                  yAxis: y
                  tooltip:
                    valueDecimals: 2
                    valueSuffix: " " + item.attribute.unit
                )
                item.serie({
                  index: serie.index
                  color: serie.color
                })
            )

      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

    getUngroupedDevicesWithNumericAttribute: () ->
      ungrouped = pimatic.getUngroupedDevices()
      return (d for d in ungrouped when d.hasAttibuteWith( (attr) => attr.type is "number" ))

    afterRenderAttribute: (elements) =>
      sliderEle = $(elements).find('select')
      pimatic.try => sliderEle.flipswitch()


    getDisplayedAttribute:  (device, attribute) ->
      console.log device, attribute
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

    getDateRange = (range = 'day') ->


    showGraph = (device, attribute, range = 'day') ->
      # unless device
      #   console.log "device not found?"
      #   return
      # unless attribute
      #   console.log "attribute not found?"
      #   return

      # {from, to} = getDateRange(range)

      # $('#chart-container').show(0)

      # $.ajax(
      #   url: "datalogger/data/#{device.deviceId}/#{attrName}"
      #   timeout: 30000 #ms
      #   type: "POST"
      #   data: 
      #     fromTime: from.getTime()
      #     toTime: to.getTime()
      # ).done( (data) ->
      #   chartInfo =
      #     device: device
      #     attrName: attrName
      #     range: range
      #     unit: attribute.unit

      #           #updateChartInfo()

      # ).fail(ajaxAlertFail)

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


  #   $("#logger-attr-values").on "click", '.show ', (event) ->
  #     sensorValueName = $(this).parents(".attr-value").data('attr-value-name')
  #     if device?
  #       showGraph(device, sensorValueName, chartInfo?.range)
  #     return

  #   $("#logger-attr-values").on "change", ".logging-switch", (event, ui) ->
  #     sensorValueName = $(this).parents(".attr-value").data('attr-value-name')
  #     action = (if $(this).val() is 'yes' then "add" else "remove")
  #     $.get("/datalogger/#{action}/#{device.deviceId}/#{sensorValueName}")
  #       .done(ajaxShowToast)
  #       .fail(ajaxAlertFail)
  #     return

  #   $("#datalogger").on "change", "#chart-select-range", (event, ui) ->
  #     val = $(this).val()
  #     showGraph(chartInfo.device, chartInfo.attrName, val)
  #     return

  # $(document).on "pagehide", '#datalogger', (event) ->
  #   if sensorListener?
  #     pimatic.socket.removeListener 'device-attribute', sensorListener
  #   return

  # $(document).on "pagebeforeshow", '#datalogger', (event) ->
  #   unless device?
  #     jQuery.mobile.changePage '#index'
  #     return false
  #   $('#chart-info').hide()

  #   pimatic.socket.on 'device-attribute', sensorListener = (data) ->
  #     unless chartInfo? then return
  #     if data.id is chartInfo.device.deviceId and data.name is chartInfo.attrName
  #       point = [new Date().getTime(), data.value]
  #       serie = $("#chart").highcharts().series[0]
  #       shift = no
  #       firstPoint = null
  #       if serie.options.data.length > 0
  #         firstPoint = serie.options.data[0]
  #       if firstPoint?
  #         {from, to} = getDateRange(chartInfo.range)
  #         if firstPoint[0] < from.getTime()
  #           shift = yes
  #       serie.addPoint(point, redraw=yes, shift, animate=yes)
  #       updateChartInfo()
  #       pimatic.showToast __('new sensor value: %s %s', data.value, chartInfo.unit)
  #     return

  #   $('#chart-container').hide()
    
  #   $("#logger-attr-values").find('li.attr-value').remove()
  #   $.get( "datalogger/info/#{device.deviceId}", (data) ->
  #     for name, logged of data.loggingAttributes
  #       attribute = device.getAttribute(name)
  #       unless attribute?
  #         console.log "could not find attribute #{name}"
  #       li = $ $('#datalogger-attr-value-template').html()
  #       li.find('.attr-value-name').text(attribute.label)
  #       li.find('label').attr('for', "flip-attr-value-#{name}")
  #       select = li.find('select')
  #         .attr('name', "flip-attr-value-#{name}")
  #         .attr('id', "flip-attr-value-#{name}")             
  #       li.data('attr-value-name', name)
  #       val = (if logged then 'yes' else 'no')
  #       select.find("option[value=#{val}]").attr('selected', 'selected')
  #       select.slider() 
  #       li.find('.show').button()
  #       $("#logger-attr-values").append li

  #     $("#logger-attr-values").listview('refresh')
  #     for name, logged of data.loggingAttributes
  #       if logged 
  #         range = $('#chart-select-range').val()
  #         showGraph(device, name, range)
  #         return
  #   ).done(ajaxShowToast).fail(ajaxAlertFail)
  #   return



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