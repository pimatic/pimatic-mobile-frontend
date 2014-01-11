# index-page
# ----------

$(document).on "pagecreate", '#index', (event) ->
  loadData()

  pimatic.socket.on "switch-status", (data) ->
    if data.state?
      value = (if data.state then "on" else "off")
      $("#flip-#{data.id}").val(value).slider('refresh')

  pimatic.socket.on "sensor-value", (data) -> updateSensorValue data

  pimatic.socket.on "rule-add", (rule) -> addRule rule
  pimatic.socket.on "rule-update", (rule) -> updateRule rule
  pimatic.socket.on "rule-remove", (rule) -> removeRule rule
  pimatic.socket.on "item-add", (item) -> addItem item
  

$(document).on "pageinit", '#index', (event) ->
  if device?
    $("#talk").show().bind "vclick", (event, ui) ->
      device.startVoiceRecognition "voiceCallback"

  $('#index #items').on "change", ".switch",(event, ui) ->
    deviceId = $(this).data('device-id')
    deviceAction = if $(this).val() is 'on' then 'turnOn' else 'turnOff'
    $.get("/api/device/#{deviceId}/#{deviceAction}")
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)
  
  $('#index #rules').on "click", ".rule", (event, ui) ->
    ruleId = $(this).data('rule-id')
    rule = pimatic.rules[ruleId]
    $('#edit-rule-form').data('action', 'update')
    $('#edit-rule-condition').val(rule.condition)
    $('#edit-rule-actions').val(rule.action)
    $('#edit-rule-active').prop "checked", rule.active
    $('#edit-rule-id').val(ruleId)
    event.stopPropagation()
    return true

  $('#index #rules').on "click", "#add-rule", (event, ui) ->
    $('#edit-rule-form').data('action', 'add')
    $('#edit-rule-condition').val("")
    $('#edit-rule-actions').val("")
    $('#edit-rule-id').val("")
    $('#edit-rule-active').prop "checked", true
    event.stopPropagation()
    return true

  $("#items").sortable(
    items: "li.sortable"
    forcePlaceholderSize: true
    placeholder: "sortable-placeholder"
    handle: ".handle"
    cursor: "move"
    revert: 100
    scroll: true
    start: (ev, ui) ->
      $("#delete-item").show()
      $("#add-a-item").hide()
      $('#items').listview('refresh')
      ui.item.css('border-bottom-width', '1px')

    stop: (ev, ui) ->
      $("#delete-item").hide()
      $("#add-a-item").show()
      $('#items').listview('refresh')
      ui.item.css('border-bottom-width', '0')
      order = for item in $("#items li.sortable")
        item = $ item
        type: item.data('item-type'), id: item.data('item-id')
      $.post "update-order", order: order
  )

  $("#items .handle").disableSelection()

  $("#delete-item").droppable(
    accept: "li.sortable"
    hoverClass: "ui-state-hover"
    drop: (ev, ui) ->
      item = {
        id: ui.draggable.data('item-id')
        type: ui.draggable.data('item-type')
      }
      $.post 'remove-item', item: item
      if item.type is 'device'
        delete pimatic.devices[item.id]
      ui.draggable.remove()
  )
  return

loadData = () ->

  $.get("/data.json")
    .done( (data) ->
      pimatic.devices = []
      pimatic.rules = []
      $('#items .item').remove()
      addItem(item) for item in data.items
      $('#rules .rule').remove()
      addRule(rule) for rule in data.rules
      pimatic.errorCount = data.errorCount
      updateErrorCount()
    ) #.fail(ajaxAlertFail)

updateErrorCount = ->
  if $('#error-count').find('.ui-btn-text').length > 0
    $('#error-count').find('.ui-btn-text').text(pimatic.errorCount)
    try
      $('#error-count').button('refresh')
    catch e
      # ignore: Uncaught Error: cannot call methods on button prior 
      # to initialization; attempted to call method 'refresh' 
  else
    $('#error-count').text(pimatic.errorCount)
  if pimatic.errorCount is 0 then $('#error-count').hide()
  else $('#error-count').show()

addItem = (item) ->
  li = if item.template?
    switch item.template 
      when "switch" then buildSwitch(item)
      when "temperature" then buildTemperature(item)
      when "presents" then buildPresents(item)
  else switch item.type
    when 'device'
      buildDevice(item)
    when 'header'
      buildHeader(item)
  li.data('item-type', item.type)
  li.data('item-id', item.id)
  li.addClass 'item'
  $('#add-a-item').before li
  li.append $('<div class="ui-icon-alt handle">
    <div class="ui-icon ui-icon-bars"></div>
  </div>')
  $('#items').listview('refresh')

buildSwitch = (switchItem) ->
  pimatic.devices[switchItem.id] = switchItem
  li = $ $('#switch-template').html()
  li.find('label')
    .attr('for', "flip-#{switchItem.id}")
    .text(switchItem.name)
  select = li.find('select')
    .attr('name', "flip-#{switchItem.id}")
    .attr('id', "flip-#{switchItem.id}")             
    .data('device-id', switchItem.id)
  if switchItem.state?
    val = if switchItem.state then 'on' else 'off'
    select.find("option[value=#{val}]").attr('selected', 'selected')
  select
    .slider() 
  return li

buildDevice = (device) ->
  pimatic.devices[device.id] = device
  li = $ $('#device-template').html()
  li.find('label').text(device.name)
  if device.error?
    li.find('.error').text(device.error)
  return li

buildHeader = (header) ->
  li = $ $('#header-template').html()
  li.find('label').text(header.text)
  return li

buildTemperature = (sensor) ->
  pimatic.devices[sensor.id] = sensor
  li = $ $('#temperature-template').html()
  li.attr('id', "device-#{sensor.id}")     
  li.find('label').text(sensor.name)
  li.find('.temperature .val').text(sensor.values.temperature)
  li.find('.humidity .val').text(sensor.values.humidity)
  return li

buildPresents = (sensor) ->
  pimatic.devices[sensor.id] = sensor
  li = $ $('#presents-template').html()
  li.attr('id', "device-#{sensor.id}")     
  li.find('label').text(sensor.name)
  if sensor.values.present is true
    li.find('.present .val').text('present').addClass('val-present')
  else 
    li.find('.present .val').text('not present').addClass('val-not-present')
  return li

updateSensorValue = (sensorValue) ->
  li = $("#device-#{sensorValue.id}")
  if sensorValue.name is 'present'
    if sensorValue.value is true
      li.find(".#{sensorValue.name} .val")
        .text('present')
        .addClass('val-present')
        .removeClass('val-not-present')
    else 
      li.find(".#{sensorValue.name} .val")
        .text('not present')
        .addClass('val-not-resent')
        .removeClass('val-present')
  else
    li.find(".#{sensorValue.name} .val").text(sensorValue.value)

addRule = (rule) ->
  pimatic.rules[rule.id] = rule 
  li = $ $('#rule-template').html()
  li.attr('id', "rule-#{rule.id}")   
  li.find('a').data('rule-id', rule.id)
  li.find('.condition').text(rule.condition)
  li.find('.action').text(rule.action)
  unless rule.active
    li.addClass('deactivated')
  li.addClass 'rule'
  $('#add-rule').before li
  $('#rules').listview('refresh')

updateRule = (rule) ->
  pimatic.rules[rule.id] = rule 
  li = $("\#rule-#{rule.id}")   
  li.find('.condition').text(rule.condition)
  li.find('.action').text(rule.action)
  if rule.active
    li.removeClass('deactivated')
  else
    li.addClass('deactivated')
  $('#rules').listview('refresh')

removeRule = (rule) ->
  delete pimatic.rules[rule.id]
  $("\#rule-#{rule.id}").remove()
  $('#rules').listview('refresh')  
