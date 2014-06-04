# index-page
# ----------

$(document).on( "pagebeforecreate", (event) ->
  # Just execute it one time
  if pimatic.templateClasses? then return
  ###
    Item classes that are shown in the Device List
  ###

  handleHTML = $('#sortable-handle-template').text()
  
  class Item
    @mapping = {
      copy: ['deviceId']
    }
    constructor: (@templData) ->
      ko.mapping.fromJS(templData, @constructor.mapping, this)
    update: (templData) -> 
      ko.mapping.fromJS(templData, @constructor.mapping, this)
    afterRender: (elements) ->
      $(elements)
      .addClass('item')
      .find("label").before($(handleHTML))

  # class HeaderItem extends Item

  #   @mapping = {
  #     copy: Item.mapping.copy.concat ['headerId', 'text']
  #   }

  #   constructor: (data) ->
  #     super(data)

  # class ButtonItem extends Item

  #   @mapping = {
  #     copy: Item.mapping.copy.concat ['buttonId', 'text']
  #   }

  #   constructor: (data) ->
  #     super(data)
  #   afterRender: (elements) -> 
  #     super(elements)
  #   onButtonPress: ->
  #     $.get("/button-pressed/#{@buttonId}").fail(ajaxAlertFail)

  # class VariableItem extends Item
  #   @mapping = {
  #     copy: Item.mapping.copy.concat ['name']
  #     observe: ["value"]
  #   }
  #   constructor: (data) ->
  #     unless data.value then data.value = null
  #     super(data)
  #   afterRender: (elements) -> 
  #     super(elements)


  class DeviceItem extends Item
    constructor: (templData, @device) ->
      super(templData)

    getAttribute: (name) -> @device.getAttribute(name)
    getItemTemplate: -> 'device'

    afterAttributeRender: (elements, attribute) ->
      $(elements)
        .addClass("attr-#{attribute.name}")
        .addClass("attr-type-#{attribute.type}")
      .parent('.attributes')
        .addClass("contains-attr-#{attribute.name}")
        .addClass("contains-attr-type-#{attribute.type}")

    error: ->
      return (
        if @deive is pimatic.nullDevice
          "Could not find a device with id: #{@templData.deviceId}"
        else null
      )


  class SwitchItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @switchId = "switch-#{templData.deviceId}"
      @switchState = ko.observable(if @getAttribute('state').value() then 'on' else 'off')
      @getAttribute('state').value.subscribe( (newState) =>
        @switchState(if newState then 'on' else 'off')
        pimatic.try => @sliderEle.flipswitch('refresh') 
      )
    onSwitchChange: ->
      stateToSet = (@switchState() is 'on')
      if stateToSet is @getAttribute('state').value()
        return
      @sliderEle.flipswitch('disable')
      deviceAction = (if @switchState() is 'on' then 'turnOn' else 'turnOff')
      pimatic.loading "switch-on-#{@switchId}", "show", text: __("switching #{@switchState()}")
      $.ajax("/api/device/#{@deviceId}/#{deviceAction}", global: no)
        .done( ajaxShowToast)
        .fail( => 
          @switchState(if @switchState() is 'on' then 'off' else 'on')
          pimatic.try( => @sliderEle.flipswitch('refresh'))
        ).always( => 
          pimatic.loading "switch-on-#{@switchId}", "hide"
          # element could be not existing anymore
          pimatic.try( => @sliderEle.flipswitch('enable'))
        ).fail(ajaxAlertFail)
    afterRender: (elements) ->
      super(elements)
      @sliderEle = $(elements).find('select')
      @sliderEle.flipswitch()

  class DimmerItem extends DeviceItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @sliderId = "switch-#{templData.deviceId}"
      dimlevel = @getAttribute('dimlevel').value
      @sliderValue = ko.observable(if dimlevel()? then dimlevel() else 0)
      @getAttribute('dimlevel').value.subscribe( (newDimlevel) =>
        @sliderValue(newDimlevel)
        pimatic.try => @sliderEle.slider('refresh') 
      )

    onSliderStop: ->
      @sliderEle.slider('disable')
      pimatic.loading(
        "dimming-#{@sliderId}", "show", text: __("dimming to %s%", @sliderValue())
      )
      $.ajax("/api/device/#{@deviceId}/changeDimlevelTo", 
          data: {dimlevel: @sliderValue()}
          global: no
        ).done(ajaxShowToast)
        .fail( => 
          pimatic.try => @sliderEle.val(@getAttribute('dimlevel').value()).slider('refresh') 
        ).always( => 
          pimatic.loading "dimming-#{@sliderId}", "hide"
          # element could be not existing anymore
          pimatic.try( => @sliderEle.slider('enable'))
        ).fail(ajaxAlertFail)
    afterRender: (elements) ->
      super(elements)
      @sliderEle = $(elements).find('input')
      @sliderEle.slider()

  class TemperatureItem extends DeviceItem

  class PresenceItem extends DeviceItem

  class ContactItem extends DeviceItem

  class ShutterItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @getAttribute('position').value.subscribe( (position) =>
        @_updateButtons(position)
      )

    onShutterDownClicked: -> 
      if @getAttribute('position').value() is 'down'
        @_ajaxCall('stop')
      else
        @_ajaxCall('moveDown')

    onShutterUpClicked: -> 
      if @getAttribute('position').value() is 'up'
        @_ajaxCall('stop')
      else
        @_ajaxCall('moveUp')
    
    _ajaxCall: (action) ->
      text = (
        switch action
          when "moveUp" then "moving up" 
          when "moveDown" then "moving down"
          when 'stop' then "stopping"
        )
      @downBtn.addClass('ui-state-disabled')
      @upBtn.addClass('ui-state-disabled')
      pimatic.loading(
        "shutter-#{@deviceId}", "show", text: __(text)
      )
      $.ajax("/api/device/#{@deviceId}/#{action}", 
          global: no
        ).done(ajaxShowToast)
        .always( => 
          pimatic.loading "shutter-#{@deviceId}", "hide"
          @downBtn.removeClass('ui-state-disabled')
          @upBtn.removeClass('ui-state-disabled')
        ).fail(ajaxAlertFail)
    _updateButtons: (position) ->
      switch position
        when 'up'
          @downBtn.removeClass('ui-btn-active')
          @upBtn.addClass('ui-btn-active')
        when 'down'
          @upBtn.removeClass('ui-btn-active')
          @downBtn.addClass('ui-btn-active')
        when 'stopped'
          @upBtn.removeClass('ui-btn-active')
          @downBtn.removeClass('ui-btn-active')

    afterRender: (elements) ->
      super(elements)
      @downBtn = $(elements).find('.shutter-down')
      @upBtn = $(elements).find('.shutter-up')
      position = @getAttribute('position').value()
      @_updateButtons(position) if position?

  # Export all classe to be extendable by plugins
  pimatic.Item = Item
  # pimatic.HeaderItem = HeaderItem
  # pimatic.ButtonItem = ButtonItem
  # pimatic.VariableItem = VariableItem
  pimatic.DeviceItem = DeviceItem
  pimatic.SwitchItem = SwitchItem
  pimatic.DimmerItem = DimmerItem
  pimatic.TemperatureItem = TemperatureItem
  pimatic.PresenceItem = PresenceItem
  pimatic.ShutterItem = ShutterItem
  pimatic.ContactItem = ContactItem

  pimatic.templateClasses = {
    null: pimatic.DeviceItem
    header: pimatic.HeaderItem
    button: pimatic.ButtonItem
    variable: pimatic.VariableItem
    device: pimatic.DeviceItem  
    switch: pimatic.SwitchItem
    dimmer: pimatic.DimmerItem
    temperature: pimatic.TemperatureItem
    presence: pimatic.PresenceItem
    contact: pimatic.ContactItem
    shutter: pimatic.ShutterItem
  }

  $(document).trigger("templateinit", [ ])

  return
)













