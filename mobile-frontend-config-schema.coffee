# #mobile-frontend configuration options
themes = [
  # legacy:
  "classic", "aloe", "candy", "melon", "mint", "royal", "sand", "water"
  # new names:
  "graphite/aloe", "graphite/candy", "graphite/melon", "graphite/mint", 
  "graphite/royal", "graphite/sand", "graphite/water", "graphite/dark",
  "jqm/classic"
]
module.exports = {
  title: "pimatic-mobile-frontend config"
  type: "object"
  properties:
    mode:
      description: "production or development mode"
      type: "string"
      enum: ["production", "development"]
      default: "production"
    theme:
      description: """jQuery Mobile theme to use. If classic then jQuery Mobiles default theme is 
        used, else the graphite theme with the corresponding color theme is used.
        """
      # http://driftyco.github.io/graphite/
      enum: themes
      default: 'graphite/water'
    flat:
      description: "Use a flat style if the theme supports it."
      type: "boolean"
      default: true
    customTitle:
      description: "Custimg title to use for the pimatic installation"
      type: "string"
      default: "pimatic"
    debug:
      description: "that to true to get additional debug outputs"
      type: "boolean"
      default: false
}