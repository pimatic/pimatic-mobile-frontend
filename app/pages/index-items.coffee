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
      copy: ['itemId', 'type', 'template']
    }

    constructor: (data) ->
      ko.mapping.fromJS(data, @constructor.mapping, this)
    update: (data) -> 
      ko.mapping.fromJS(data, @constructor.mapping, this)
    afterRender: (elements) ->
      $(elements)
      .addClass('item')
      .find("label").before($(handleHTML))

  class HeaderItem extends Item

    @mapping = {
      copy: Item.mapping.copy.concat ['headerId', 'text']
    }

    constructor: (data) ->
      super(data)

  class ButtonItem extends Item

    @mapping = {
      copy: Item.mapping.copy.concat ['buttonId', 'text']
    }

    constructor: (data) ->
      super(data)
    afterRender: (elements) -> 
      super(elements)
    onButtonPress: ->
      $.get("/button-pressed/#{@buttonId}").fail(ajaxAlertFail)

  class VariableItem extends Item
    @mapping = {
      copy: Item.mapping.copy.concat ['name']
      observe: ["value"]
    }
    constructor: (data) ->
      unless data.value then data.value = null
      super(data)
    afterRender: (elements) -> 
      super(elements)


  class DeviceAttribute 

    @mapping = {
      observe: ["value"]
    }

    constructor: (data) ->
      # Allways create an observable for value:
      unless data.value? then data.value = null
      ko.mapping.fromJS(data, @constructor.mapping, this)
      @valueText = ko.computed( =>
        value = @value()
        unless value?
          return __("unknown")
        if @type is 'boolean'
          unless @labels? then return value.toString()
          else if value is true then @labels[0] 
          else if value is false then @labels[1]
          else value.toString()
        else return value.toString()
      )
      @unitText = if @unit? then @unit else ''

  class DeviceItem extends Item

    @mapping = {
      attributes:
        create: ({data, parent, skip}) => new DeviceAttribute(data)
        key: (data) => data.name
      observe: ["name", "attributes"]
    }

    constructor: (data) ->
      super(data)

    getAttribute: (name) ->
      attribute = null
      for attr in @attributes()
        if attr.name is name
          attribute = attr
          break
      return attribute

    afterAttributeRender: (elements, attribute) ->
      $(elements)
        .addClass("attr-#{attribute.name}")
        .addClass("attr-type-#{attribute.type}")
      .parent('.attributes')
        .addClass("contains-attr-#{attribute.name}")
        .addClass("contains-attr-type-#{attribute.type}")

    updateAttribute: (attrName, attrValue) ->
      attribute = @getAttribute(attrName)
      if attribute?
        attribute.value(attrValue)

  class SwitchItem extends DeviceItem

    constructor: (data) ->
      super(data)
      @switchId = "switch-#{data.deviceId}"
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
    constructor: (data) ->
      super(data)
      @sliderId = "switch-#{data.deviceId}"
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

    constructor: (data) ->
      super(data)
      @getAttribute('position').value.subscribe( (position) =>
        @_updateButtons(position)
      )

    onShutterDownClicked: -> @_ajaxCall('lowerDown')
    onShutterUpClicked: -> @_ajaxCall('liftUp')
    _ajaxCall: (action) ->
      text = (if action is "liftUp" then "Up" else "Down")
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

    afterRender: (elements) ->
      super(elements)
      @downBtn = $(elements).find('.shutter-down')
      @upBtn = $(elements).find('.shutter-up')
      position = @getAttribute('position').value()
      @_updateButtons(position) if position?

  # Export all classe to be extendable by plugins
  pimatic.Item = Item
  pimatic.HeaderItem = HeaderItem
  pimatic.ButtonItem = ButtonItem
  pimatic.VariableItem = VariableItem
  pimatic.DeviceItem = DeviceItem
  pimatic.SwitchItem = SwitchItem
  pimatic.DimmerItem = DimmerItem
  pimatic.TemperatureItem = TemperatureItem
  pimatic.PresenceItem = PresenceItem
  pimatic.ShutterItem = ShutterItem
  pimatic.ContactItem = ContactItem

  pimatic.templateClasses = {
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
  return
)













