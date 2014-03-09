module.exports = (env) ->

  Q = env.require 'q'
  _ = env.require 'lodash'
  M = env.matcher

  class ButtonPredicateProvider extends env.predicates.PredicateProvider

    _listener: {}

    constructor: (@mobile) ->

    parsePredicate: (predicate, context) ->

      matchCount = 0
      matchingButton = 0
      end = () => matchCount++
      onButtonMatch = (m, button) => matchingButton = button

      allButtons = _(@mobile.config.items)
        .filter((i) => i.type is "button")
        .map((i) => [i, i.text]).value()

      m = M(predicate, context)
        .match('the ', optional: true)
        .match(allButtons, onButtonMatch)
        .match(' button', optional: true)
        .match(' is', optional: true)
        .match(' pressed')
      matchCount = m.getMatchCount()

      if matchCount is 1
        match = m.getFullMatches()[0]
        return {
          token: match
          nextInput: m.inputs[0]
          predicateHandler: new ButtonPredicateHandler(matchingButton.id)
        }
      else if matchCount > 1
        context?.addError(""""#{predicate.trim()}" is ambiguous.""")
      return null




  class ButtonPredicateHandler extends env.predicates.PredicateHandler

    constructor: (@itemId) ->
      @buttonPressedListener = (item) => if item.id is @itemId then @emit('change', 'event')
      @mobile.on 'button pressed', @buttonPressedListener

    getValue: -> Q(false)
    destroy: -> @mobile.removeListener 'button pressed', @buttonPressedListener
    getType: -> 'event'


  return ButtonPredicateProvider
