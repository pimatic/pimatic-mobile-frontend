( ->

  setIconClass = ($ele, icon) ->
    # remove old icon-class
    classes = (
      cl for cl in $ele.attr('class').split(" ") when cl.lastIndexOf('ui-icon-') isnt 0
    )
    classes.push('ui-icon-'+icon)
    # add new one
    $ele.attr("class", classes.join(" "));

  ko.bindingHandlers.jqmbutton = {

    init: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      return


    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      # Handle text binding
      if valueUnwrapped.text?
        textValue = ko.unwrap(valueUnwrapped.text)
        $ele.text(textValue)
      if valueUnwrapped.icon?
        icon =  ko.unwrap(valueUnwrapped.icon)
        setIconClass($ele, icon)
      return
  }

  ko.bindingHandlers.jqmlistitem = {
    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      # Handle icon binding
      if value.icon?
        icon = ko.unwrap(value.icon)
        setIconClass($ele, icon)
  }

  ko.bindingHandlers.jqmenabled = {
    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      if valueUnwrapped
        $ele.textinput('enable'); 
      else
        $ele.textinput('disable'); 
      return
  }

  ko.bindingHandlers.jqmchecked = {
    init: ko.bindingHandlers.checked.init
    update: (element, valueAccessor) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      #calling 'refresh' only if already enhanced by JQM
      $(element).checkboxradio("refresh")
      return
    }


  ko.bindingHandlers.sortable = {
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      # cached vars for sorting events
      value = valueAccessor()
      valueUnwrapped = ko.toJS(value)

      dataList = value.data
      customOptions = valueUnwrapped.options or {}
      # The differents between the index in the array and the index in the html dom
      sourceIndex = null

      defaultOptions = {
        items: "li.sortable"
        forcePlaceholderSize: true
        placeholder: "sortable-placeholder"
        handle: ".handle"
        cursor: "move"
        revert: 100
        scroll: true
        containment: "parent"
      }

      events = ["activate", "beforeStop", "change", "create", "deactivate", "out", "over", "receive", 
        "remove", "sort", "start", "stop", "update"]

      for name, v of customOptions
        if name in events
          customOptions[name] = v.bind(bindingContext.$data)

      options = ko.utils.extend(customOptions, defaultOptions)

      bindingEventHandler = {
        # cache the item index when the dragging starts
        start: (event, ui) =>
          data = ko.dataFor(ui.item[0])
          sourceIndex = dataList.indexOf(data) 
          ui.item.css('border-bottom-width', '1px')
          # signal start sorting
          value.isSorting(yes) if value.isSorting?
        # capture the item index at end of the dragging
        # then move the item
        stop: (event, ui) =>
          data = ko.dataFor(ui.item.prev()[0])
          ui.item.css('border-bottom-width', '0')
          # get the new location item index
          targetIndex = dataList.indexOf(data)
          if targetIndex == -1 then targetIndex = 0 # No item was before this one
          else if targetIndex < sourceIndex then targetIndex += 1

          console.log "prev", data, targetIndex
          if sourceIndex >= 0 and targetIndex >= 0 and sourceIndex isnt targetIndex
            #  get the item to be moved
            underlyingList = ko.utils.unwrapObservable(dataList)
            item = underlyingList[sourceIndex]
            # notify 'beforeChange' subscribers
            dataList.valueWillMutate()
            # move from source index ...
            underlyingList.splice sourceIndex, 1
            # ... to target index
            underlyingList.splice targetIndex, 0, item
            # notify subscribers
            dataList.valueHasMutated()
            # signal stop sorting
          value.isSorting(no) if value.isSorting?
          return true
      }

      for evtType, handler of bindingEventHandler
        do (evtType, handler) =>
          customHandler = customOptions[evtType] or (=>) 
          options[evtType] = -> 
            handler.apply(this, arguments)
            return customHandler.apply(bindingContext.$data, arguments)
            
      sortable = $(element).sortable(options)
  }

  ko.bindingHandlers.jqmselectvalue = {
    init: (element, valueAccessor, allBindingsAccessor, viewModel) ->
      if typeof ko.bindingHandlers.value.init isnt "undefined"
        ko.bindingHandlers.value.init element, valueAccessor, allBindingsAccessor, viewModel

    update: (element, valueAccessor, allBindingsAccessor, viewModel) ->
      if typeof ko.bindingHandlers.value.update isnt "undefined"
        ko.bindingHandlers.value.update element, valueAccessor, allBindingsAccessor, viewModel
      $(element).selectmenu("refresh", true)
  }

  ko.bindingHandlers.droppable = {
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      # cached vars for sorting events
      value = valueAccessor()
      valueUnwrapped = ko.toJS(value)
      customOptions = valueUnwrapped.options or {}

      defaultOptions = {
        accept: "li.sortable"
        hoverClass: "ui-state-hover"
      }

      events = ["activate", "create", "deactivate", "drop", "out", "over"]
      for name, value of customOptions
        if name in events
          customOptions[name] = value.bind(bindingContext.$data)

      options = ko.utils.extend(customOptions, defaultOptions)
      $(element).droppable(options)
  }

  ko.bindingHandlers.dragslide = {
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      # cached vars for sorting events
      value = valueAccessor()
      valueUnwrapped = ko.toJS(value)
      customOptions = valueUnwrapped.options or {}

      li = $(element)
      rule = bindingContext.$rawData
      action = null

      showDragMessage = (msg) =>
        $('.drag-message')
        .text(msg)
        .css(
          top: li.position().top
          height: li.outerHeight()
          'line-height': li.outerHeight() + "px"
        ).fadeIn(500)

      li.draggable(
        axis: "x"
        revert: true
        handle: 'a'
        zIndex: 100
        scroll: false
        revertDuration: 200
        drag: ( event, ui ) => 
          # offset of the helper is 15 at start
          offsetX = ui.offset.left-15
          if offsetX < -120
            unless action is "deactivate"
              showDragMessage(__('deactivate rule')).addClass('deactivate').removeClass('activate')
              action = "deactivate"
          else if offsetX > 120
            unless action is "activate"
              showDragMessage(__('activate rule')).addClass('activate').removeClass('deactivate')
              action = "activate"
          else
            if action?
              $('.drag-message').fadeOut(500)
              action = null

        stop: => 
          $('.drag-message').text('').fadeOut().removeClass('activate').removeClass('deactivate')
          if action?
            pimatic.loading "saveactivate", "show", text: __(action)
            $.ajax("/api/rule/#{rule.id}/#{action}",
              global: false
            ).always( ->
              pimatic.loading "saveactivate", "hide"
            ).done(ajaxShowToast).fail(ajaxAlertFail)
      )

      ###
        Some realy dirty hacks to allow vertical scralling
      ###
      if $.ui.mouse.prototype._touchStart?
        uiDraggable = li.data('uiDraggable')

        # Capture the last mousedown/touchstart event
        lastVmouseDown = null
        li.on('vmousedown', (event) =>
          if $(event.target).parent('.handle').length then return
          lastVmouseDown = event
        )

        uiDraggable._isDragging = no
        # If the mouse
        li.on('vmousemove', (event) =>
          if $(event.target).parent('.handle').length then return
          unless lastVmouseDown is null
            deltaX = Math.abs(event.pageX - lastVmouseDown.pageX)
            deltaY = Math.abs(event.pageY - lastVmouseDown.pageY)
            # detect horizontal drag
            if deltaX > deltaY and deltaX > 5 and not uiDraggable._isDragging
              # https://code.google.com/p/android/issues/detail?id=19827
              event.originalEvent.preventDefault();
              event.stopPropagation();
              originalEvent = lastVmouseDown.originalEvent
              uiDraggable._isDragging = yes
              $.ui.mouse.prototype._touchStart.apply(
                uiDraggable, [originalEvent]
              )
              lastVmouseDown = null
        )
  }

)()