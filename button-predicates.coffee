module.exports = (env) ->

  Q = env.require 'q'
  _ = env.require 'lodash'
  M = env.matcher

  class ButtonPredicateProvider extends env.predicates.PredicateProvider

    _listener: {}

    constructor: (@mobile) ->

    _parsePredicate: (predicate, context) ->

      matchCount = 0
      matchingButton = 0
      end = () => matchCount++
      onButtonMatch = (m, button) => matchingButton = button

      allButtons = _(@mobile.config.items)
        .filter((i) => i.type is "button")
        .map((i) => [i, i.text]).value()

      M(predicate, context)
        .match('the ', optional: true)
        .match(allButtons, onButtonMatch)
        .match(' button', optional: true)
        .match(' is', optional: true)
        .match(' pressed')
        .onEnd(end)

      if matchCount is 1
        return info =
          itemId: matchingButton.id
      else if matchCount > 1
        context?.addError(""""#{predicate.trim()}" is ambiguous.""")
      return null

    canDecide: (predicate, context) ->
      info = @_parsePredicate predicate, context
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