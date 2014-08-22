# #mobile-frontend configuration options
module.exports = {
  title: "pimatic-mobile-frontend config"
  type: "object"
  properties:
    mode:
      doc: "production or development mode"
      type: "string"
      enum: ["production", "development"]
      default: "production"
    theme:
      doc: """jQuery Mobile theme to use. If classic then jQuery Mobiles default theme is used, 
        else the graphite theme with the corresponding color theme is used.
        """
      # http://driftyco.github.io/graphite/
      enum: ["classic", "aloe", "candy", "melon", "mint", "royal", "sand", "slate", "water"]
      default: 'water'
    flat:
      doc: "Use a flat style if the theme supports it."
      type: "boolean"
      default: true
    debug:
      doc: "that to true to get additional debug outputs"
      type: "boolean"
      default: false
}