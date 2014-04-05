###

gaze.js

(c) Ralf Biedert, 2014 - http://gaze.io
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###


# Version of this script
VERSION = "%%VERSION%%"

# Should suffice for the moment of getting the global
global = window

# Make backup of previous gaze object if there was any
_gaze = global.gaze

# Extensions that have been registered
extensions = {}
extensionorder = [] # order in which to initialize ["raw", "filtered", "dwell", ...]



# Potential problems
#   error = terminal failure to eye tracking until reinitialized
#   warning = temporary failure or data likely corrupt
#   info = might be problem, might be not
#
problems = {
    "E_CONNECTIONCLOSED": {
        message: "Connection to the tracker closed unexpectedly. All gaze data halted."
        type: "error"
    }

    "E_NOTIMPLEMENTED": {
        message: "This feature is not implemented at the moment."
        type: "error"
    }

    "W_DATASTALL": {
        message: "The gaze relay (or the eye tracker) unexpectedly stopped
                sending data. The application is currently unaware of gaze."
        type: "warning"
    }

    "I_MOUSEFALLBACK": {
        message: "No eye tracker was found on your system. We will fall back to mouse emulation."
        type: "info"
    }
}



### Handlers Class ###
handlers = () ->
    @_handlers = []
    return @

handlers.prototype = {
    ### Adds something to this handlers and returns a handle ###
    add: (x) ->
        that = @
        size = @_handlers.length

        @_handlers.push x

        # Construct removal handle
        handle = {
            handler: x
            remove: () -> that.remove this.handler
        }

        # If old size was 0, we are populated now
        if size == 0 then @onpopulated()

        return handle

    ### Checks if there are elements in the handlers ###
    has: () -> @_handlers.length > 0

    ### Calls every handler with the given message ###
    invoke: (msg) ->
        for handler in @_handlers
            handler msg

    ### Call f for each handler ###
    each: (f) ->
        for handler in @_handlers
            f handler

    ### Removes something from these handlers ###
    remove: (x) ->
        size = @_handlers.length
        @_handlers = @_handlers.filter (y) -> x isnt y

        if size > 0 and @_handlers.length == 0
            @onempty()

    onpopulated: () ->
    onempty: () ->
}



### Vector Class ###
### Doing math inline style for highest performance. ###
vector = (x, y, z) ->
    @isvector = true

    # Initialize empty
    if not x?
        @data = []

    # Initialize with length or array
    else if not y?
        if x.length?
            @data = x.slice(0)
        else
            @data = new Array(x)

    # Initialize with x and y and / or z
    else if not z?
        @data = [x, y]
    else
        @data = [x, y, z]

    return @


vector.prototype = {
    ### Adds a number, vector or array ###
    add: (v) ->
        if typeof v == "number"
            @data[i] += v for dish, i in @data
            return @

        d = if v.isvector then v.data else v
        @data[i] += d[i] for e, i in d
        return @



    ### Subtracts a number, vector or array ###
    sub: (v) ->
        if typeof v == "number"
            @data[i] -= v for dish, i in @data
            return @

        d = if v.isvector then v.data else v
        @data[i] -= d[i] for e, i in d
        return @


    ### Multiplies elements with a number, or element-wise ###
    mul: (v) ->
        if typeof v == "number"
            @data[i] *= v for e, i in @data
            return @

        d = if v.isvector then v.data else v
        @data[i] *= d[i] for e, i in d
        return @


    ### Computes the mode of this vector. ###
    mode: () ->
        # Code stolen from
        # http://stackoverflow.com/questions/1053843/get-the-element-with-the-highest-occurrence-in-an-array
        tmp = []
        max = ''
        maxi=0

        for k in @data

            if(tmp[k]) then tmp[k]++ else tmp[k]=1

            if(maxi<tmp[k])
                max=k
                maxi=tmp[k]

        return max


    ### Sets all elements to random ###
    rand: () -> @data[i] = Math.random() for e, i in @data; return @

    ### Sets all elements to a given value ###
    set: (c) -> @data[i] = c for e, i in @data; return @

    ### Sets all elements to 0 ###
    zeros: () -> @set(0); return @

    ### Returns n-dimensional distance ###
    distance: () ->
        rval = 0
        rval += (value * value) for value in @data
        return Math.sqrt(rval)

    ### Misc helpers ###
    dim: () -> data.length
    get: (i) -> if i? then @data[i] else @data
    x: () -> @data[0]
    y: () -> @data[1]
    z: () -> @data[2]

    ### Clones this vector ###
    clone: () -> return new vector(@data)
}



### Gaze Class ###
gaze = (@global) ->
    @_document = @global.document
    @_initialized = false
    @_onframe = new handlers()
    @_onframeconfig = new handlers()
    @_onproblem = new handlers()
    @_currentframe = {}
    return @


### Extend the gaze object with more functions  ###
gaze.extension = (fns, module) ->
    if not module
        module = {}
        module.id = ("unnamed" + Math.random()).replace(".", "")

    for key, value of fns
        if gaze.fn[key]
            console.log("Module '" + module.id + "' overrides '" + key + "()'")

        gaze.fn[key] = value

    # Safety check we don't override anything
    if module.functions
        alert("Extension module must not have attribute .functions")

    # Transcribe problem IDs
    if module.problems then problems[key] = value for key, value of module.problems

    # Store functions we added
    module.functions = fns

    # And store extension
    extensions[module.id] = module

    # Eventually update the extensionorder based on its dependency graph
    extensionorder = (name for name of extensions)
    extensionorder.sort (a, b) ->
        # If b does not have any dependencies, b goes left
        if not b.dependencies then return -1

        # If b depends on a, b goes right
        if b.dependencies.indexOf(a) >= 0 then return 1
        return -1



### Core methods ###
gaze.fn = gaze.prototype = {
    ### Initializes object and connects to an eye tracker ###
    init: (@url) ->
        if @_initialized then deinit()

        # Initialize extensions in proper order
        for id in extensionorder
            module = extensions[id]

            if module.init then module.init @, module

        gaze = @
        wasconnected = false
        connector = gaze.connectors["relay"]

        frame = (frame) -> gaze.frame frame
        status = (event) ->
            if event.type == "open"
                wasconnected = true

            if event.type == "close"
                if wasconnected then gaze.problem("E_CONNECTIONCLOSED")
                else
                    gaze.problem("I_MOUSEFALLBACK")

                    connector = gaze.connectors["mouse"]
                    gaze._tracker = connector(url, status, frame)

            if event.type == "error"
                if wasconnected
                    console.log event


        # Next initialize the eye tracker, or at least try
        @_tracker = connector(url, status, frame)
        @_initialized = true

        # Push empty frame as a hack to wake up watchdog
        frame {}


    ### Informs registered listeners about a problem ###
    problem: (id) ->
        problem = problems[id] or { message: id }
        problem.id = id
        @_onproblem.invoke problem

    ### The global object where this was bound to ###
    global: global

    ### Register handler called when there was a problem ###
    onproblem: (handler) -> @_onproblem.add handler

    ### Deinitializes this object, can be used again afterwards. ###
    deinit: () ->
        @_tracker.deinit()

        for id, module of extensions
            if module.deinit then module.deinit @, module

        @_initialized = false

    ### Returns a new handlers object that can be used internally ###
    handlers: () -> new handlers()

    ### Sets the desired frame rate ###
    fps: (fps) ->

    ### Pushes a frame to all registered listeners or retrieves the currently
    pushed frame. ###
    frame: (frame) ->
        if frame
            @_currentframe = frame

            # First let all extensions do their work
            for id in extensionorder
                module = extensions[id]
                if module.onframe
                    module.onframe frame, @, module

            # Then push frame over official channel
            @_onframe.invoke frame
        else @_currentframe

    ### Registers for a frame ###
    onframe: (handler) -> @_onframe.add handler

    ### Returns a new vector ###
    vector: (x, y, z) -> new vector(x, y, z)

    ### Returns the version ###
    version: () -> VERSION

    ### Returns true if gaze handling should be performed (e.g., window in
    focus / foreground) ###
    isactive: () -> true


    ### Returns the distance of a point and a rect or two points. ###
    distance: (x, y, rx, ry, rw, rh) ->
        # In case we only have 2 parameters, treat as two points a = [x, y], b = [x, y]

        if not rx?
            a = x; b = y;
            return Math.sqrt( (a[0]-b[0])**2 + (a[1]-b[1])**2 )

        # In case we only have 4 parameters, treat as two points in form x1 y1, x2, y2
        if not rw?
            x1 = x; y1 = y; x2 = rx; y2 = ry
            return Math.sqrt( (x1-x2)**2 + (y1-y2)**2 )

        #
        #        I   |    II    |  III
        #      ======+==========+======   --yMin
        #       VIII |  IX (in) |  IV
        #      ======+==========+======   --yMax
        #       VII  |    VI    |   V
        #

        # In this case do real distance of point and rect
        if x < rx # Region I, VIII, or VII
            if y < ry # I
                return @distance(x, y, rx, ry)
            else if y > ry + rh # VII
                return @distance(x, y, rx, ry + rh)
            else # VIII
                return rx - x
        else if x > rx + rw # Region III, IV, or V
            if y < ry # III
                return @distance(x, y, rx + rw, ry)
            else if y > ry + rh # V
                return @distance(x, y, rx + rw, ry + rh)
            else # IV
                return x - (rx + rw)
        else # Region II, IX, or VI
            if y < ry # II
                return ry - y
            else if y > ry + rh # VI
                return y - (ry + rh)
            else # IX
                return 0.0

        throw "This should never happen."


    ### Sets or returns an extension ###
    extension: (fns, module) ->
        if not fns and not module
            return extensions

        if typeof fns == "string"
            return extensions[fns]

        gaze.extension(fns, module)


    ### Removes this gaze object again from global, restores the previous
    one and return this. ###
    noconflict: (x) ->
        @global.gaze = _gaze
        return this

}



### WATCHDOG ###
gaze.extension({} , {
    id: "watchdog"
    framecount: 0
    watchdog: null

    init: (gaze, module) ->
        time = Date.now()
        lastcount = 0
        lastwarn = 0

        check = () ->
            if module.framecount == lastcount and module.framecount != lastwarn
                gaze.problem("W_DATASTALL")
                lastwarn = module.framecount

            lastcount = module.framecount

        gaze.onframe () ->
            # If this was the first frame, set up watchdog
            if not module.framecount++
                module.watchdog = setInterval check, 1500

    deinit: (gaze, module) -> clearInterval module.watchdog
})



### QUALITY ###
gaze.extension({} , {
    id: "quality"

    onframe: (frame, gaze, module) ->
        if not frame.departTime then return

        frame.latency = Date.now() - frame.departTime
})



### STORAGE ###
gaze.extension({
    ### Stores or retrieves a value ###
    storage: (key, value) ->
        manager = {
            set: (key, value) ->
                if not localStorage? then return
                return localStorage.setItem(key, value)

            get: (key, dflt) ->
                if not localStorage? then return
                return localStorage.getItem(key) or dflt
        }

        if key? and value? then manager.set(key, value)
        if key? and not value? then  manager.get(key)

        return manager
    } , {

    id: "storage"
})





### BROWSER ###
gaze.extension({
    ### Returns the browser ID ###
    browser: () ->
        if !!global.opera || navigator.userAgent.indexOf(' OPR/') >= 0 then return "opera"
        if typeof InstallTrigger != 'undefined' then return "firefox"
        if Object.prototype.toString.call(global.HTMLElement).indexOf('Constructor') > 0 then return "safari"
        if !!global.chrome then return "chrome"
        if false || !!global.document.documentMode then return "ie"
        return "unknown"


    ### Returns the logical pixel ratio to the OS pixel ratio, i.e., how large the
    browser zoom level is. ###
    browserpixelratio: () ->
        if global.devicePixelRatio then return global.devicePixelRatio
        else if global.screen.deviceXDPI then return global.screen.deviceXDPI / global.screen.logicalXDPI

        @problem("W_ZOOMRATIO")
        return 1


    ### Given a frame part with "screen" coordinates, update browser /
    geometry information in it  ###
    updategeometry: (part) ->
        # Compute variables not yet given in filtered
        if not part.screen then return

        part.screenX = part.screen[0]
        part.screenY = part.screen[1]


        if not part.window
            part.window = @screen2window(part.screen[0], part.screen[1])

        part.windowX = part.window[0]
        part.windowY = part.window[1]


        if not part.document
            part.document = [part.window[0] + global.pageXOffset,
                             part.window[1] + global.pageYOffset]

        part.documentX = part.document[0]
        part.documentY = part.document[1]


        if not part.windowdist
            part.windowdist = @distance(part.screen[0], part.screen[1], global.screenX, global.screenY, global.outerWidth, global.outerHeight) == 0


    ### Converts a screen pixel position to a window position ###
    screen2window: (x, y) -> return [x, y] # Is overriden in module.init()!

    ### Override the isactive method ###
    isactive: () -> global.document.hasFocus()

    ### Returns a new ID or make sure we have one ###
    id: (element) ->
        ext = @extension("browser")

        # Make sure we return the element id if it exists
        if element and element.id then return element.id

        id = "gioid" + ext.lastID++

        # No element given? Just return the ID.
        if not element? then return id

        # Eventually set it and return it
        element.setAttribute("id", id);
        return id


    ### Performs a hit test on the given window coordinate and checks if the
    given element is actually visible ###
    hittest: (x, y, element) ->
        # Check if we actually hit the element.
        hittest = global.document.elementFromPoint(x , y)

        # Check if we hit it or its parent
        if hittest != null
            while true
                if hittest == element
                    return true

                # Make sure we dont run in a loop
                if not hittest.parentNode? then break
                if hittest.parentNode == hittest then break
                hittest = hittest.parentNode

        return false

    ### Notify user with a bubble ###
    notifiybubble: (string, config) ->
        document = global.document

        note = document.createElement "div"
        note.style.position = "fixed"
        note.style.top = "10px"
        note.style.right = "-250px"
        note.style.padding = "20px"
        note.style.color = "white"
        note.style.background = "#333"
        note.style.width = "200px"
        note.style.fontFamily = "Helvetica"
        note.style.fontSize = "10pt"
        note.style.opacity = "1"
        #note.style.transition = 'opacity 0.3s, right 0.3s'
        note.style.border = '1px solid #555'
        note.style.borderRadius = '5px'
        note.style.zIndex = "99999999"

        links = ""

        if config and config.links
            links = "<br/><br/>"
            for link in config.links
                links += """<a style='color:#4da6ff; text-decoration: none;'
                    onclick="window.open('""" + link.url + """', 'helper')"
                    href=''>&raquo; """ + link.text + "</a><br/>"

        note.innerHTML = """
        <div onclick='this.parentNode.parentNode.removeChild(this.parentNode);'>
            <img style='position:absolute; top: 10px; left:10px;
                padding-right:5px; padding-bottom:3px;' width='20px' src='http://downloads.gaze.io/api/logo.mini.png'>
            <div style='position:relative; left:18px; top:-8px; padding-right:10px;'>
            """ + string + links +  """
            </div>
        </div>"""
        document.body.appendChild note

        setTimeout(
            () ->
                note.style.opacity = "1"
                note.style.right = "50px"
            ,1)

        return note


}, {
    id: "browser"

    ### Last ID number emitted by gaze.io framework ###
    lastID: 0

    depends: ["storage"]

    problems: {
        "W_ZOOMRATIO": {
            message: "Unable to determine browser zoom ratio. Your results may be wrong. Try
            zooming to 100% and hope for the best (and use another browser)."
            type: "warning"
        }
    }

    browser: "unknown"
    desktopzoom: 1.0
    windowoffset: [0, 0]

    ### Click handler to translate coordinates ###
    click: (evt) ->
      p = @_gaze.browserpixelratio()
      z = @desktopzoom

      dx = 0
      dy = 0

      if @browser == "ie"
        dx = - ((evt.screenX) - (global.screenX * p) - (evt.clientX * p))
        dy = - ((evt.screenY) - (global.screenY * p) - (evt.clientY * p))

      if @browser == "chrome"
        dx = - ((evt.screenX) - (global.screenX) - (evt.clientX * p))
        dy = - ((evt.screenY) - (global.screenY) - (evt.clientY * p))

      if @browser == "safari"
        dx = - ((evt.screenX) - (global.screenX) - (evt.clientX * p))
        dy = - ((evt.screenY) - (global.screenY) - (evt.clientY * p))

      if @browser == "firefox"
        dx = - ((evt.screenX * z) - (global.screenX * p) - (evt.clientX * p))
        dy = - ((evt.screenY * z) - (global.screenY * p) - (evt.clientY * p))


      # DX now has the offsets in of the client area start relative to the
      # reported window.screenX and window.screenY positions in physical screen pixels

      @windowoffset = [dx, dy]

      @_gaze.storage("_gaze_windowoffsetx", dx)
      @_gaze.storage("_gaze_windowoffsety", dy)


    deinit: (gaze, module) -> global.document.removeEventListener @click

    onframe: (frame, gaze, module) ->
        if not frame.screen then return
        if not frame.screen.scaleToLogic then return

        # Update local desktop zoom if changed
        if module.desktopzoom != 1.0 / frame.screen.scaleToLogic
            module.desktopzoom = 1.0 / frame.screen.scaleToLogic

            # And set variable
            gaze.storage("_gaze_desktopzoom", module.desktopzoom)


    init: (gaze, module) ->
        module._gaze = gaze

        document = global.document

        # Compute some values and get others from storage
        module.browser = gaze.browser()
        module.desktopzoom = parseFloat(gaze.storage("_gaze_desktopzoom")) or 1.0
        module.windowoffset[0] = parseInt(gaze.storage("_gaze_windowoffsetx")) or 0
        module.windowoffset[1] = parseInt(gaze.storage("_gaze_windowoffsety")) or 0

        global.document.addEventListener 'click', @click.bind(@)

        # Actual value converter
        rx = (p, x, y) -> return x
        ry = (p, x, y) -> return x

        # Pixel conversion function
        convert = (x, y) ->
            if typeof x == "undefined"
                return [x, x]

            if typeof y == "undefined"
                y = x[1]
                x = x[0]

            p = gaze.browserpixelratio()
            return [rx(p, x, y), ry(p, x, y)]

        # Sets the appropriate screen2window function based on browser
        if module.browser == "chrome"
                rx = (p, x, y) -> (x - global.screenX + module.windowoffset[0]) / p
                ry = (p, x, y) -> (y - global.screenY + module.windowoffset[1]) / p

        if module.browser == "ie"
                rx = (p, x, y) -> (x - global.screenX * p + module.windowoffset[0]) / p
                ry = (p, x, y) -> (y - global.screenY * p + module.windowoffset[1]) / p

        if module.browser == "safari" #TODO: safari currently wrong, measure again
                rx = (p, x, y) -> (x - global.screenX + module.windowoffset[0]) / p
                ry = (p, x, y) -> (y - global.screenY + module.windowoffset[1]) / p

        if module.browser == "firefox"
                rx = (p, x, y) -> (x - global.screenX * p + module.windowoffset[0]) / p
                ry = (p, x, y) -> (y - global.screenY * p + module.windowoffset[1]) / p

        gaze.screen2window = convert
})





### USERHELP ###
gaze.extension({} , {
    id: "userhelp"

    handlerfocus: null
    handlerblur: null

    init: (gaze, module) ->
        # Setup general problem handling
        module.remove = gaze.onproblem (problem) ->
            config = {}
            config.links = []

            config.links.push {
                url: "http://gaze.io/faq/#" + problem.id
                text: "Get more help"
            }

            # Only bubble for some messages
            if not (problem.type == "warning" or problem.type == "error" or problem.id == "I_MOUSEFALLBACK")
                return

            # Special handling for I_MOUSEFALLBACK
            if problem.id == "I_MOUSEFALLBACK"
                config.links[0].text = "Have a tracker or need help?"

            gaze.notifiybubble(problem.message, config)


        # Put this in here at the moment. Might need to find a better place.
        message = null

        module.handlerfocus = (e) ->
            if message == null then return
            message.parentNode.removeChild(message)

        module.handlerblur = (e) ->
            message = gaze.notifiybubble("The document has lost focus. Eye tracking data will not be processed at the moment.")

        # Setup non-focus handler
        global.addEventListener('focus', module.handlerfocus);
        global.addEventListener('blur', module.handlerblur);


    deinit: (gaze, module) -> module.remove.remove()
})






### RAW ###
gaze.extension({
    ### Adds a raw listener and returns a removal handle ###
    onraw: (listener) ->
        ext = @extension("raw")
        ext._handlers.add listener
}, {
    id: "raw"

    ### Initialize this module ###
    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        removal = null

        func = (packet) ->
            # In case we don't have the focus, we don't do anything
            if not gaze.isactive() then return
            module._handlers.invoke packet.raw

        # Called when the first handler was added or removed
        module._handlers.onpopulated = () -> removal = gaze.onframe func
        module._handlers.onempty = () -> removal.remove()
})



### FILTERED ###
gaze.extension({
    ### Adds a filtered listener and returns a removal handle ###
    onfiltered: (listener) ->
        ext = @extension("filtered")
        ext._handlers.add listener

    filter: (filter) ->
        ext = @extension("filtered")
}, {
    id: "filtered"
    depends: ["raw", "browser"]

    ### Called when a new frame arrives ###
    onframe: (frame, gaze, module) ->
        # Nothing to filter, no raw = nothing to do
        if not frame.filtered and not frame.raw then return

        # Filter data here ...
        if not frame.filtered and frame.raw
            throw "Not implemented"
            frame.filtered = {}

        # And eventually convert to local coordinate system
        gaze.updategeometry frame.filtered



    ### Initialize this module ###
    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        removal = null

        func = (packet) ->
            # In case we don't have the focus, we don't do anything
            if not gaze.isactive() then return
            module._handlers.invoke packet.filtered

        # Called when the first handler was added or removed
        module._handlers.onpopulated = () -> removal = gaze.onframe func
        module._handlers.onempty = () -> removal.remove()
})




### FIXATION ###
gaze.extension({
    ### Adds a filtered listener and returns a removal handle ###
    onfixation: (listener) ->
        ext = @extension("fixation")
        ext._handlers.add listener
}, {
    id: "fixation"
    depends: ["filtered", "browser"]

    radiusthreshold: 50
    currentfixation: null
    outliers: []

    ### Creates a new fixation structure ###
    fixationstruct: (point) ->
        {
            _center: point
            _points: [point]
        }

    ### Called to update the current fixation ###
    computefixation: (gaze, point, newfixation, continuedfixation) ->
        if not point then return

        # If we are not in a fixation, go ahead and create object
        if not this.currentfixation
            this.currentfixation = this.fixationstruct(point)

        currentfixation = this.currentfixation

        # Check how far away we are
        distance = gaze.distance(currentfixation._center, point)
        if isNaN distance then distance = 999999

        # If we have an outlier ...
        if distance > this.radiusthreshold
            this.outliers.push point

            # Very crude fixation start detection ...
            if this.outliers.length > 3
                this.outliers = []
                this.currentfixation = this.fixationstruct(point)
                this.currentfixation.type = "start"


                # And call our handler
                newfixation this.currentfixation

        else
            currentfixation._points.push point

        # And call our handler
        this.currentfixation.type = "continue"
        continuedfixation this.currentfixation



    ### Called when a new frame arrives ###
    onframe: (frame, gaze, module) ->
        # Nothing to filter, no raw = nothing to do
        if not frame.filtered then return

        newfixation = (fixation) ->
            frame.fixation = fixation
            frame.fixation.screen = [fixation._center[0], fixation._center[1]]

            gaze.updategeometry frame.fixation

            # Eventually call handlers
            module._handlers.invoke frame.fixation

        continuedfixation = (fixation) ->
            # Called when a fixation was continued
            frame.fixation = fixation


        # Call our handler function
        module.computefixation gaze, frame.filtered.screen, newfixation, continuedfixation



    ### Initialize this module ###
    init: (gaze, module) -> module._handlers = gaze.handlers()
})




### GAZE OVER / OUT ###
gaze.extension({
    ongazeover: (elements, listener, options) ->
        ext = @extension("gazeover")

        if typeof elements == "string"
            elements = @_document.querySelectorAll elements

        if not elements.length # Our test to see if it is an array
            elements = [elements]

        # Construct defaults
        if not options? then options = { }
        if not typeof options == "object" then throw "If third parameter is given to ongazeover, it needs to be a map."

        # Convert radius to over and out
        if options.radius
            options.radiusover = options.radius
            options.radiusout = options.radius + 15

        # Make sure we actually have all properties we need
        if not options.radiusout? then options.radiusout = 15  # gaze has to be within this many pixel from the edge to trigger "over"
        if not options.radiusover? then options.radiusover = 0 # gaze has to be outside this many pixel from the edge to trigger "out"
        if not options.continueover? then options.continueover = false # should continue to send "over" messages while inside every frame?
        if not options.visibilitytest? then options.visibilitytest = false # if we should check if the element is actually visible
        if not options.transaction? then options.transaction = false # if we should also emit "begin" and "end" messages for events
        if not options.hittest? then options.hittest = false # if we should also emit "begin" and "end" messages for events

        # Ensure all elements have IDs
        @id(element) for element in elements

        # We need this for internal handling
        options.gazeovermap = {}

        ext._handlers.add [elements, listener, options]
}, {
    id: "gazeover"
    depends: ["browser", "filtered", "fixation"]

    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        document = gaze.global.document
        removal = null

        func = (p) ->
            # In case we don't have the focus, we don't do anything
            if not gaze.isactive() then return

            # Get the scale factor since the user might have zoomed in or out
            scale = gaze.browserpixelratio()

            # Every thing that was registered with on... will be treated individually
            module._handlers.each (f) ->
                elements = f[0]
                callback = f[1]
                options = f[2]

                gazeovermap = options.gazeovermap
                hittest = options.hittest
                visibilitytest = options.visibilitytest

                # If requested, start a transaction
                if options.transaction then callback {type:"begin", elements:elements, options: options}

                for e in elements

                    # Ignore elements removed from tree
                    if not document.body.contains(e) then continue
                    if not p.window then continue

                    r = e.getBoundingClientRect()
                    distance = gaze.distance(p.window[0], p.window[1], r.left, r.top, r.width, r.height)

                    visible = true
                    hit = true
                    id = e.id

                    if visibilitytest then visible = gaze.hittest(r.left + r.width / 2 , r.top + r.height / 2, e)
                    if hittest then hit = gaze.hittest(p.window[0], p.window[1], e)

                    # Check if we hit the element
                    if distance <= options.radiusover / scale and visible and hit
                        if not gazeovermap[id] or options.continueover
                            callback {type:"over", element: e, distance: distance, gazewindow: p.window, options: options}
                            gazeovermap[id] = true

                    else if gazeovermap[id]
                            callback {type:"out", element: e, distance: distance, gazewindow: p.window, options: options}
                            gazeovermap[id] = false


                # If requested, end the transaction
                if options.transaction then callback {type:"end", elements:elements, options: options}


        # Called when the first handler was added or removed
        module._handlers.onpopulated = () -> removal = gaze.onfiltered func
        module._handlers.onempty = () -> removal.remove()
})



### SELECT ###
gaze.extension({
    onselect: (elements, listener, options) ->
        ext = @extension("select")

        if not options? then options = {}
        if not options.p? then options.p = (e) -> 1 # the likelihood function (e) -> [0, 1]
        if not options.overlapping? then options.overlapping = false # If we should try to handle overlapping elements

        options.selectradius = 100

        # Setup gazeover for select function
        options.transaction = true
        options.visibilitytest = false
        options.hittest = false
        options.continueover = true # Have to be continuous since we need updated distances
        options.radiusover = options.selectradius
        options.radiusout = options.selectradius

        # Add our own helper map for all elements we consider
        options.selectmap = {}
        options.selectlistener = listener

        @ongazeover(elements, ext.selecthandler.bind(ext), options)
}, {
    id: "select"
    depends: ["gazeover"]
    gaze: null

    ### Store gaze object for handler ###
    init: (gaze) -> @gaze = gaze

    ### Compute likelihood for every batch of elements ###
    processor: (elements, options) ->
        selectmap = options.selectmap

        all = []

        # Now compute for every element
        for element in elements
            map = selectmap[element.id]

            if not map then continue
            if not map.selectover then continue

            map.element = element
            map.p = options.p(element)
            map.likelihood = map.p * (options.selectradius - map.selectdistance)

            all.push(map)


        # In case there was none left, emit an empty event
        if all.length == 0
            options.selectlistener( { type: "empty" } )
            return


        # Get best element
        all.sort (a, b) -> return b.likelihood - a.likelihood

        # Make sure we have top element
        best = all[0]

        # Call with this element if it changed
        if not options.lastselected or options.lastselected != best.element
            options.selectlistener({type:"selected", element: best.element})

        options.lastselected = best.element



    ### Handle gaze over/out messages ###
    selecthandler: (event) ->
        options = event.options
        selectmap = options.selectmap

        # After the end of the batch call we do our calculations
        if event.type == "end"
            @processor(event.elements, options)

        # For every element that was over, store distances and other metrics
        # (Note that we get continuous over messages)
        if event.type == "over"
            element = event.element

            # Make sure we have something for the element
            if not selectmap[element.id] then selectmap[element.id] = {}

            map = selectmap[element.id]
            map.selectover = true
            map.selectdistance = event.distance


            # Make sure we have small non-null distance
            if map.selectdistance < 10 then map.selectdistance = 10

            # If we actually hit the element, bump score even higher
            if options.overlapping and @gaze.hittest(event.gazewindow[0], event.gazewindow[1], element)
                map.selectdistance = 5



        # If it was out, disregard it
        if event.type == "out"
            element = event.element

            map = selectmap[element.id]
            map.selectover = false
})






### DWELL ###
gaze.extension({
    ondwell: (elements, listener, options) ->
        ext = @extension("dwell")

        if not options? then options = {}

        if typeof options == "number"
            number = options
            options = {}
            options.dwellthreshold = number

        if not options.dwellthreshold? then options.dwellthreshold = 500 # The dwell time to activate
        if not options.dwelldecay? then options.dwelldecay = 100 # The decay amount every frame user is not there

        options._dwelllistener = listener

        @ongazeover(elements, ext.dwellhandler, options)
}, {
    id: "dwell"
    depends: ["gazeover"]

    dwellhandler: (event) ->
        element = event.element
        now = Date.now()

        if event.type == "over"
            # Clear old timeout if there was one
            if element._dwelltimeout then clearTimeout(element._dwelltimeout)

            # TODO Gracefully handle out and over again (i.e., decay just a little)

            # See if there was residual time
            time = event.options.dwellthreshold

            element._dwelltimeout = setTimeout( () ->
                    event.options._dwelllistener()
                , time)

        if event.type == "out"
            if element._dwelltimeout then clearTimeout(element._dwelltimeout)
            delete element._dwelltimeout

})





### TRACKER MOUSE ###
gaze.extension({} , {
    id: "tracker.mouse"

})





### Connectors we use as backends ###
gaze.connectors = {
    "relay": (url, status, frame) ->
        url = "ws://127.0.0.1:44042" if not url?

        i = 0
        socket = new WebSocket(url)
        socket.onerror = status
        socket.onopen = status
        socket.onclose = status
        socket.onmessage = (evt) -> frame JSON.parse(evt.data)

        return {
            tracker: null
            type: "relay"
            frameinfo: {
                filtered: {

                }
            }
            deinit: () -> socket.close()
        }

    "mouse": (url, status, frame) ->
        last = null; timer = null
        number = 0

        motion = (e) -> last = e
        tick = () ->

            w = if last then new vector(last.clientX, last.clientY) else new vector(2).zeros()
            w.add(new vector(2).rand().add(-0.5).mul(20))

            frame {
                # Single latest raw event
                raw: {
                    left: {
                        screen: [0, 0]
                        valid: true
                        pupil: 0.0
                    }

                    right: {
                        screen: [0, 0]
                        valid: true
                        pupil: 0.0
                    }

                    timestamp: 0
                }

                # All raw events (including current) that have been recorded
                # since the last frame, but were not transmitted due to
                # FPS limits.
                rawhist: [
                    {}, {},
                ]

                # Current pre-filtered data
                filtered: {
                    window: [w.x(), w.y()]
                    screen: [w.x() + global.screenX, w.y() + global.screenX]
                    valid: false
                    windowdist: 0
                }
            }

        document.addEventListener('mousemove', motion, false);
        timer = setInterval tick, 30

        return {
            tracker: null
            type: "mouse"
            frameinfo: {
                filtered: {

                }
            }
            deinit: () -> clearInterval timer
        }
}


### Set global object ###
global.gaze = new gaze(global)
global.gaze.connectors = gaze.connectors







