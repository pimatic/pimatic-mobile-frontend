( ->

  ko.bindingHandlers.jqmbutton = {
    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      # Handle text binding
      if value.text?
        textValue = ko.unwrap(value.text)
        $bt = $ele.find('.ui-btn-text')
        if $bt.length > 0
          $bt.text(textValue)
        else
          $ele.text(textValue)

      # Handle icon binding
      if value.icon?
        iconValue = ko.unwrap(value.icon)
        if $ele.find('.ui-icon').length > 0
          $ele.buttonMarkup(icon: iconValue)
        else
          $ele.attr('data-icon', iconValue)

      # Refresh the button
      try
        if $ele.data('role') is 'button'
          $ele.button('refresh')
      catch e
        # ignore button not initialise
  }

  ko.bindingHandlers.jqmlistitem = {
    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)

      # Handle icon binding
      if value.icon?
        iconValue = ko.unwrap(value.icon)
        if $ele.find('.ui-icon').length > 0
          $ele.buttonMarkup(icon: iconValue)
        else
          $ele.attr('data-icon', iconValue)
  }


  ko.bindingHandlers.sortable = {
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      # cached vars for sorting events
      value = valueAccessor()
      valueUnwrapped = ko.toJS(value)

      dataList = value.data
      customOptions = valueUnwrapped.options or {}
      # The differents between the index in the array and the index in the html dom
      indexOffset = valueUnwrapped.indexOffset or 0
      sourceIndex = null

      defaultOptions = {
        items: "li.sortable"
        forcePlaceholderSize: true
        placeholder: "sortable-placeholder"
        handle: ".handle"
        cursor: "move"
        revert: 100
        scroll: true
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
          sourceIndex = ui.item.index() - indexOffset 
          $('#items').listview('refresh')        
          ui.item.css('border-bottom-width', '1px')
          # signal start sorting
          value.isSorting(yes) if value.isSorting?
        # capture the item index at end of the dragging
        # then move the item
        stop: (event, ui) =>
          ui.item.css('border-bottom-width', '0')
          # get the new location item index
          targetIndex = ui.item.index() - indexOffset
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
      }

      for evtType, handler of bindingEventHandler
        do (evtType, handler) =>
          customHandler = customOptions[evtType] or (=>) 
          options[evtType] = -> 
            handler.apply(this, arguments)
            return customHandler.apply(bindingContext.$data, arguments)
            
      sortable = $(element).sortable(options)
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
              originalEvent = lastVmouseDown.originalEvent
              uiDraggable._isDragging = yes
              $.ui.mouse.prototype._touchStart.apply(
                uiDraggable, [originalEvent]
              )
              lastVmouseDown = null
        )
  }

)()