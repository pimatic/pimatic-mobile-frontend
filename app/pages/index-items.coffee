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
    constructor: (@templData) ->
      ko.mapper.fromJS(@templData, @constructor.mapping, this)
    update: (@templData) -> 
      ko.mapper.fromJS(@templData, @constructor.mapping, this)
    afterRender: (elements) ->
      $(elements)
      .addClass('item')
      .find("label").before($(handleHTML))

  class HeaderItem extends Item
    constructor: (groups) -> 
      if groups.length is 0
        @title = 'Ungrouped'
      else
        @title = ''
        for g, i in groups
          if i isnt 0 then @title += ', '
          @title += g.name()
    afterRender: -> #nop
    getItemTemplate: -> 'header'

  class DeviceItem extends Item
    @mapping = {
      $default: 'ignore'
      deviceId: 'copy'
    }
    constructor: (templData, @device) ->
      super(templData)
      @name = @device.name
      @deviceId = templData.deviceId

    getAttribute: (name) -> @device.getAttribute(name)
    getItemTemplate: -> @device.template

    afterAttributeRender: (elements, attribute) ->
      ele = $(elements)
      ele
        .addClass("attr-#{attribute.name}")
        .addClass("attr-type-#{attribute.type}")
      ele
        .parent('.attributes')
          .addClass("contains-attr-#{attribute.name}")
          .addClass("contains-attr-type-#{attribute.type}")

    error: ->
      return (
        if @device is pimatic.nullDevice
          "Could not find a device with id: #{@templData.deviceId}"
        else null
      )
    toJS: () -> ko.mapper.toJS(this, @constructor.mapping)

    labelTooltipHtml: => 
      html = """
        <div>ID: #{@deviceId}</div>
        <div>Class: #{@device.config.class}</div>
      """
      buttons = []
      if @device.config.xLink
        buttons.push """<a href="#{@device.config.xLink}" target="_blank">Link</a>"""
      if @device.config.xButton
        buttons.push """
          <a href="#" id="to-device-xButton"
          data-deviceId="#{@device.id}">#{@device.config.xButton}</a>
        """
      if @device.hasAttibuteWith( (attr) => attr.type in ["number", "boolean"])
        buttons.push """  
          <a href="#" id="to-graph-page"
          data-deviceId="#{@device.id}">Graph</a>
        """
      if pimatic.hasPermission('devices', 'write')
        buttons.push """
          <a href="#" id="to-device-editor-page"
          data-deviceId="#{@device.id}">Edit Device</a>
        """
      if buttons.length > 0
        html += "<div>#{buttons.join('')}</div>"
      return html

    getConfig: (name) ->
      if @device.config[name]?
        return @device.config[name]
      else
        return @device.configDefaults[name]

  class SwitchItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @switchId = "switch-#{templData.deviceId}"
      stateAttribute = @getAttribute('state')
      unless stateAttribute?
        throw new Error("A switch device needs an state attribute!")
      @switchState = ko.observable(if stateAttribute.value() then 'on' else 'off')
      stateAttribute.value.subscribe( (newState) =>
        @_restoringState = true
        @switchState(if newState then 'on' else 'off')
        pimatic.try => @sliderEle.flipswitch('refresh')
        @_restoringState = false
      )

    onSwitchChange: ->
      if @_restoringState then return
      stateToSet = (@switchState() is 'on')
      value = @getAttribute('state').value()
      if stateToSet is value
        return
      @sliderEle.flipswitch('disable')
      deviceAction = (if @switchState() is 'on' then 'turnOn' else 'turnOff')

      doIt = (
        if @device.config.xConfirm then confirm __("""
          Do you really want to turn %s?
        """, "#{@device.name()} #{__(@switchState())}")
        else yes
      ) 

      restoreState = (if @switchState() is 'on' then 'off' else 'on')

      if doIt
        pimatic.loading "switch-on-#{@switchId}", "show", text: __("switching #{@switchState()}")
        @device.rest[deviceAction]({}, global: no)
          .done(ajaxShowToast)
          .fail( => 
            @_restoringState = true
            @switchState(restoreState)
            pimatic.try( => @sliderEle.flipswitch('refresh'))
            @_restoringState = false
          ).always( => 
            pimatic.loading "switch-on-#{@switchId}", "hide"
            # element could be not existing anymore
            pimatic.try( => @sliderEle.flipswitch('enable'))
          ).fail(ajaxAlertFail)
      else
        @_restoringState = true
        @switchState(restoreState)
        pimatic.try( => @sliderEle.flipswitch('enable'))
        pimatic.try( => @sliderEle.flipswitch('refresh'))
        @_restoringState = false

    afterRender: (elements) ->
      super(elements)
      @sliderEle = $(elements).find('select')
      state = @getAttribute('state')
      if state.labels?
        capitaliseFirstLetter = (s) -> s.charAt(0).toUpperCase() + s.slice(1)
        @sliderEle.find('option[value=on]').text(__(capitaliseFirstLetter state.labels[0]))
        @sliderEle.find('option[value=off]').text(__(capitaliseFirstLetter state.labels[1]))

      @sliderEle.flipswitch()
      $(elements).find('.ui-flipswitch').addClass('no-carousel-slide')

  class DimmerItem extends DeviceItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @sliderId = "switch-#{templData.deviceId}"
      dimAttribute = @getAttribute('dimlevel')
      unless dimAttribute?
        throw new Error("A dimmer device needs an dimlevel attribute!")
      dimlevel = dimAttribute.value
      @sliderValue = ko.observable(if dimlevel()? then dimlevel() else 0)
      dimAttribute.value.subscribe( (newDimlevel) =>
        @sliderValue(newDimlevel)
        pimatic.try => @sliderEle.slider('refresh') 
      )

    onSliderStop: ->
      @sliderEle.slider('disable')
      pimatic.loading(
        "dimming-#{@sliderId}", "show", text: __("dimming to %s%", @sliderValue())
      )
      @device.rest.changeDimlevelTo( {dimlevel: @sliderValue()}, global: no).done(ajaxShowToast)
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
      $(elements).find('.ui-slider').addClass('no-carousel-slide')

  class TemperatureItem extends DeviceItem
    getItemTemplate: => 'device'

  class PresenceItem extends DeviceItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @getAttribute('presence').value.subscribe( =>
        @updateClass()
      )

    getItemTemplate: => 'device'

    afterRender: (elements) ->
      super(elements)
      @presenceEle = $(elements).find('.attr-presence')
      @updateClass()

    updateClass: ->
      value = @getAttribute('presence').value()
      if @presenceEle?
        switch value
          when true
            @presenceEle.addClass('value-present')
            @presenceEle.removeClass('value-absent')
          when false
            @presenceEle.removeClass('value-present')
            @presenceEle.addClass('value-absent')
          else
            @presenceEle.removeClass('value-absent')
            @presenceEle.removeClass('value-present')
      return

  class ContactItem extends DeviceItem
    getItemTemplate: => 'device'

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
        doIt = (
          if @device.config.xConfirm then confirm __("
          Do you really want to press \"%s\"?
        ", __('down'))
          else yes
        )
        if doIt
          @_ajaxCall('moveDown')

    onShutterUpClicked: -> 
      if @getAttribute('position').value() is 'up'
        @_ajaxCall('stop')
      else
        doIt = (
          if @device.config.xConfirm then confirm __("
          Do you really want to press \"%s\"?
        ", __('up'))
          else yes
        )
        if doIt
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
      @device.rest[action]({}, global: no).done(ajaxShowToast)
        .always( => 
          pimatic.loading "shutter-#{@deviceId}", "hide"
          @downBtn.removeClass('ui-state-disabled')
          @upBtn.removeClass('ui-state-disabled')
        ).fail(ajaxAlertFail)
    _updateButtons: (position) ->
      unless @downBtn? then return
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

  class InputItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @type = @getConfig('type')
      # The value in the input
      @inputValue = ko.observable()

      @inputAttr = @getAttribute('input')
      @inputValue(@inputAttr.value())

      attrValue = @inputAttr.value()
      @inputAttr.value.subscribe( (value) =>
        @inputValue(value)
        attrValue = value
      )

      # input changes -> update variable value
      ko.computed( =>
        textValue = @inputValue()
        if attrValue isnt textValue
          if @type is "string"
            @changeInputTo(textValue)
          else if @type is "number"
            if textValue? and attrValue? and parseFloat(attrValue) isnt parseFloat(textValue)
              numVal = parseFloat(textValue)
              if isNaN(textValue) or numVal isnt numVal #only true for NaN
                swal("Oops...", __("#{textValue} is not a number."), "error")
                @inputValue(attrValue)
                return
              @changeInputTo(numVal)
      ).extend({ rateLimit: { timeout: 1000, method: "notifyWhenChangesStop" } })

    changeInputTo: (value) ->
      @device.rest.changeInputTo({value}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
        .always( => ; )

    afterRender: (elements) ->
      super(elements)
      @input = $(elements).find('input')
      if @type is "number"
        min = @getConfig('min')
        max = @getConfig('max')
        step = @getConfig('step')
        if min?
          @input.attr('min', min)
        if max?
          @input.attr('max', max)
        @input.attr('step', step)
        @input.spinbox().autosizeInput(space: 30)
      else
        @input.autosizeInput(space: 5)

  class InputTimeItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @type = @getConfig('type')
      # The value in the input
      @inputValue = ko.observable()

      @inputAttr = @getAttribute('input')
      @inputValue(@inputAttr.value())

      attrValue = @inputAttr.value()
      @inputAttr.value.subscribe( (value) =>
        @inputValue(value)
        attrValue = value
      )

      # input changes -> update variable value
      ko.computed( =>
        textValue = @inputValue()
        timePattern = ///
            ^ # begin of line
            (
            [01]?       # 0, 1 or nothing and
            [0-9]       # 0-9 leads to every possible hour up to 19
            |           # or
            2[0-3]      # 20-23 -> exclude 24-29 this way
            )
            :
            [0-5][0-9]  # minutes
            ///
        hourPattern = /// ^[01]?[0-9]|2[0-3] ///
        if attrValue isnt textValue
          if textValue.match timePattern
            @changeInputTo(textValue)
          else
            if textValue.match hourPattern
              @changeInputTo("#{textValue}:00")
            else
              swal("Oops...", __("#{textValue} is not a vaild time."), "error")
      ).extend({ rateLimit: { timeout: 1000, method: "notifyWhenChangesStop" } })

    changeInputTo: (value) ->
      @device.rest.changeInputTo({value}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
        .always( => ; )

    afterRender: (elements) ->
      super(elements)
      @input = $(elements).find('input')
      min = @getConfig('min')
      max = @getConfig('max')
      step = @getConfig('step')
      if min?
        @input.attr('min', min)
      if max?
        @input.attr('max', max)
      @input.attr('step', step)
      @input.timebox().autosizeInput(space: 10)

  class ButtonsItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)

    getItemTemplate: => 'buttons'

    onButtonPress: (button) =>
      doIt = (
        if button.confirm then confirm __("
          Do you really want to press \"%s\"?
        ", button.text)
        else yes
      ) 
      if doIt
        @device.rest.buttonPressed({buttonId: button.id}, global: no)
          .done(ajaxShowToast)
          .fail(ajaxAlertFail)

  class MuscicplayerItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @currentTitle = @device.getAttribute('currentTitle').value

      @playButtonIcon = ko.computed( =>
        state = @device.getAttribute('state').value
        return (
          if state() is 'play' then 'pause'
          else 'play'
        )
      )

    getItemTemplate: => 'musicplayer'

    sendPlayerAction: (action) =>
      @device.rest[action]({})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

    togglePlay: () =>
      state = @device.getAttribute('state').value
      if state() is 'play'
        action = 'pause'
      else
        action = 'play'
      @sendPlayerAction(action)

  class ThermostatItem extends DeviceItem
    
    constructor: (templData, @device) ->
      super(templData, @device)
      # The value in the input
      @inputValue = ko.observable()

      # temperatureSetpoint changes -> update input + also update buttons if needed
      @stAttr = @getAttribute('temperatureSetpoint')
      @inputValue(@stAttr.value())

      attrValue = @stAttr.value()
      @stAttr.value.subscribe( (value) =>
        @inputValue(value)
        attrValue = value
      )

      # input changes -> call changeTemperature
      ko.computed( =>
        textValue = @inputValue()
        if textValue? and attrValue? and parseFloat(attrValue) isnt parseFloat(textValue)
          @changeTemperatureTo(parseFloat(textValue))
      ).extend({ rateLimit: { timeout: 1000, method: "notifyWhenChangesStop" } })

      @synced = @getAttribute('synced').value

    afterRender: (elements) ->
      super(elements)
      # find the buttons
      @autoButton = $(elements).find('[name=autoButton]')
      @manuButton = $(elements).find('[name=manuButton]')
      @boostButton = $(elements).find('[name=boostButton]')
      @ecoButton = $(elements).find('[name=ecoButton]')
      @comfyButton = $(elements).find('[name=comfyButton]')
      # @vacButton = $(elements).find('[name=vacButton]')
      @input = $(elements).find('.spinbox input')
      @valvePosition = $(elements).find('.valve-position-bar')
      @input.spinbox()

      @updateButtons()
      @updatePreTemperature()
      @updateValvePosition()

      @getAttribute('mode')?.value.subscribe( => @updateButtons() )
      @stAttr.value.subscribe( => @updatePreTemperature() )
      @getAttribute('valve')?.value.subscribe( => @updateValvePosition() )
      return

    # define the available actions for the template
    modeAuto: -> @changeModeTo "auto"
    modeManu: -> @changeModeTo "manu"
    modeBoost: -> @changeModeTo "boost"
    modeEco: -> @changeTemperatureTo "#{@device.config.ecoTemp}"
    modeComfy: -> @changeTemperatureTo "#{@device.config.comfyTemp}"
    modeVac: -> @changeTemperatureTo "#{@device.config.vacTemp}"
    setTemp: -> @changeTemperatureTo "#{@inputValue.value()}"

    updateButtons: ->
      modeAttr = @getAttribute('mode')?.value()
      switch modeAttr
        when 'auto'
          @manuButton.removeClass('ui-btn-active')
          @boostButton.removeClass('ui-btn-active')
          @autoButton.addClass('ui-btn-active')
        when 'manu'
          @manuButton.addClass('ui-btn-active')
          @boostButton.removeClass('ui-btn-active')
          @autoButton.removeClass('ui-btn-active')
        when 'boost'
          @manuButton.removeClass('ui-btn-active')
          @boostButton.addClass('ui-btn-active')
          @ecoButton.removeClass('ui-btn-active')
          @comfyButton.removeClass('ui-btn-active')
          @autoButton.removeClass('ui-btn-active')
      return

    updatePreTemperature: ->
      if parseFloat(@stAttr.value()) is parseFloat("#{@device.config.ecoTemp}")
        @boostButton.removeClass('ui-btn-active')
        @ecoButton.addClass('ui-btn-active')
        @comfyButton.removeClass('ui-btn-active')
      else if parseFloat(@stAttr.value()) is parseFloat("#{@device.config.comfyTemp}")
        @boostButton.removeClass('ui-btn-active')
        @ecoButton.removeClass('ui-btn-active')
        @comfyButton.addClass('ui-btn-active')
      else
        @ecoButton.removeClass('ui-btn-active')
        @comfyButton.removeClass('ui-btn-active')
      return

    updateValvePosition: ->
      valveVal = @getAttribute('valve')?.value()
      if valveVal?
        @valvePosition.css('height', "#{valveVal}%")
        @valvePosition.parent().css('display', '')
      else
        @valvePosition.parent().css('display', 'none')

    changeModeTo: (mode) ->
      @device.rest.changeModeTo({mode}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

    changeTemperatureTo: (temperatureSetpoint) ->
      @input.spinbox('disable')
      @device.rest.changeTemperatureTo({temperatureSetpoint}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
        .always( => @input.spinbox('enable') )


  class TimerItem extends DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)
      @startButtonIcon = ko.computed( =>
        running = @device.getAttribute('running').value
        return (
          if running() then 'stop'
          else 'play'
        )
      )

    getItemTemplate: => 'timer'

    sendTimerAction: (action) =>
      @device.rest[action]({})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

    toggleRunning: () =>
      running = @device.getAttribute('running').value
      if running()
        action = 'stopTimer'
      else
        action = 'startTimer'
      @sendTimerAction(action)


  # Export all classes to be extendable by plugins
  pimatic.Item = Item
  pimatic.HeaderItem = HeaderItem
  pimatic.ButtonsItem = ButtonsItem

  pimatic.DeviceItem = DeviceItem
  pimatic.SwitchItem = SwitchItem
  pimatic.DimmerItem = DimmerItem
  pimatic.TemperatureItem = TemperatureItem
  pimatic.PresenceItem = PresenceItem
  pimatic.ShutterItem = ShutterItem
  pimatic.ContactItem = ContactItem
  pimatic.MuscicplayerItem = MuscicplayerItem
  pimatic.ThermostatItem = ThermostatItem
  pimatic.TimerItem = TimerItem
  pimatic.InputItem = InputItem
  pimatic.InputTimeItem = InputTimeItem

  pimatic.templateClasses = {
    null: pimatic.DeviceItem
    header: pimatic.HeaderItem
    buttons: pimatic.ButtonsItem
    variable: pimatic.VariableItem
    device: pimatic.DeviceItem  
    switch: pimatic.SwitchItem
    dimmer: pimatic.DimmerItem
    temperature: pimatic.TemperatureItem
    presence: pimatic.PresenceItem
    contact: pimatic.ContactItem
    shutter: pimatic.ShutterItem
    musicplayer: pimatic.MuscicplayerItem
    thermostat: pimatic.ThermostatItem
    timer: pimatic.TimerItem
    input: pimatic.InputItem
    inputTime: pimatic.InputTimeItem
  }

  $(document).trigger("templateinit", [ ])
  $(document).trigger("templateready", [ ])
  return
)













