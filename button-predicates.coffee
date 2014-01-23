module.exports = (env) ->

  Q = env.require 'q'

  class ButtonPredicateProvider extends env.predicates.PredicateProvider

    _listener: {}

    constructor: (@mobile) ->

    _parsePredicate: (predicate) ->
      # Just to be sure convert the predicate to lower case.
      predicate = predicate.toLowerCase()
      # Then try to match:
      matches = predicate.match ///
        ^(.+?) # the button name
        (?:\s+button)? # optional button
        (?:\s+is\s+|\s+) # followed by a whitespace or "is "
        pressed$ # and ends with pressed
      ///

      if matches?
        buttonName = matches[1]
        for item in @mobile.config.items
          if item.type is "button"
            if @_matchesIdOrName item.text, buttonName
              return info =
                itemId: item.id

    # Checks if `find` matches the id or name of the button lower case ignoring "the " prefixes 
    # in the search string and name.
    _matchesIdOrName: (name, find) ->
      cleanFind = find.toLowerCase().replace('the ', '').trim()
      cleanName = name.toLowerCase().replace('the ', '').trim()
      return cleanFind is cleanName

    canDecide: (predicate) ->
      info = @_parsePredicate predicate
      return if info? then 'event' else no

    isTrue: (predicate) -> Q false

    notifyWhen: (id, predicate, callback) ->
      info = @_parsePredicate predicate
      unless info? then throw new Error "Can not decide #{predicate}."

      @mobile.on 'button pressed', buttonPressedListener = (item) =>
        if item.id is info.itemId then callback('event') 

      @_listener[id] =
        itemId: info.itemId
        destroy: => @mobile.removeListener 'button pressed', buttonPressedListener

    cancelNotify: (id) ->
      listener = @_listener[id]
      if listener?
        listener.destroy()
      delete @_listener[id]

  return ButtonPredicateProvider