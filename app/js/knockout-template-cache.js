(function (ko) {
    var self = { };
 
    var cachedTemplatesDomDataKey = "__cached_template__";
 
    //
    // When rendering a template, a source is what returns either the text or the already-created DOM
    // nodes to clone. The default implementation of a template source in knockout doesn't cache the
    // DOM nodes that it creates, and instead requests the text of the <script> tag the template is
    // defined in and parses it as HTML. This is inefficient, and it is much better to cache and clone
    // the nodes.
    //
    // This part is responsible for cahing the DOM nodes on the <script> tag that corresponds with the
    // template definition the first time the template is requested.
    //
    self.templateSources = function (domElem)
    {
        // Note: This inherits from the domElement template source. This gives basic storage of the
        //       corresponding dom element for the template.
        var templateSources = {
            'elem': domElem,
            '__proto__': new ko.templateSources.domElement(domElem)
        };
 
        // Return the HTML of the template directly, used the first time that DOM nodes are requested
        // to be parsed and create the nodes.
        templateSources.text = function (value)
        {
            if (arguments.length === 0)
            {
                return templateSources.elem.text;
            }
            else
            {
                templateSources.elem.text = value;
            }
        };
 
        // Return the DOM nodes that correspond to this template source. The first time this is called,
        // the text of the <script> tag for the template is parsed and the DOM nodes are generated and
        // cached on the element.
        templateSources.nodes = function (value)
        {
            if (arguments.length === 0)
            {
                // Grab the cached data from the <script> tag. This may not exist yet.
                var templateData = ko.utils.domData.get(templateSources.elem, cachedTemplatesDomDataKey);
 
                // If the cached data doesn't exist yet, create it.
                if (!templateData)
                {
                    var templateText = templateSources.text();
                    var parsedNodes = ko.utils.parseHtmlFragment(templateText);
 
                    // Wrap the parsed DOM nodes in a div. This can be any element type, but the topmost node
                    // in the tree is consumed by KO and not rendered as part of the template.
                    var compiledNodes = document.createElement("div");
                    for(var i = 0; i < parsedNodes.length; i ++)
                    {
                        compiledNodes.appendChild(parsedNodes[i]);
                    }
 
                    ko.utils.domData.set(templateSources.elem, cachedTemplatesDomDataKey, {cachedNodes: compiledNodes});
 
                    return compiledNodes;
                }
                return templateData.cachedNodes;
            }
        };
 
        return templateSources;
    };
 
    //
    // Since we want to use the caching template source above for all of our templates, ensure that
    // when the rendering engine creates the input DOM nodes to render the template, that it uses
    // the caching source that we defined above. Additionally, this is responsible for caching the
    // document and template nodes to avoid multiple lookups in the DOM every time a template is
    // rendered.
    //
    self.templateEngine = function ()
    {
        // Note: This inherits all the default behavior of the template engine that comes with KO except
        //       for how the template sources are created..
        var templateEngine = {
            '__proto__': new ko.nativeTemplateEngine()
        };
 
        templateEngine.cachedDoc = undefined;
 
        // The returned templateSource is used to render the template.
        templateEngine.makeTemplateSource = function (template, templateDocument)
        {
            var incomingDoc = templateDocument || document;
 
            var cachedDoc = templateEngine.cachedDoc;
            if (!templateEngine.cachedDoc)
            {
                // If this is the first time we are being called, cache the doc. This assumes that all
                // templates are loaded from the same document!
                cachedDoc = {
                    'doc': incomingDoc,
                    'cachedTemplates': { }
                };
 
                templateEngine.cachedDoc = cachedDoc;
            }
 
            // See if we have previously cached the <script> element that corresponds with this template, if
            // we haven't, cache it, create a new source for it, and continue.
            var elem = cachedDoc.cachedTemplates[template];
            if (!elem)
            {
                var domElem = cachedDoc.doc.getElementById(template);
 
                elem = new self.templateSources(domElem);
 
                cachedDoc.cachedTemplates[template] = elem;
            }
 
            return elem;
        };
 
        return templateEngine;
    };
 
    // Let KO know that we are supplying our own template engine (though most of the behavior comes from the
    // default KO template engine).
    var engine = self.templateEngine();
    if (engine instanceof ko.templateEngine)
    {
        ko.setTemplateEngine(engine);
    }
 
    return self;
})(ko);