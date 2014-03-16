###

gaze.js 

(c) Ralf Biedert, 2014
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
VERSION = 0.1

# Should suffice for the moment of getting the global
global = window

# Make backup of previous gaze object if there was any
_gaze = global.gaze

# Extensions that have been registered
extensions = {} 

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

    "W_DATASTALL": {
        message: "The gaze relay (or the eye tracker) unexpectedly stopped 
                sending data. The application is currently unaware of gaze."
        type: "warning"
    }        

    "I_MOUSEFALLBACK": {
        message: "Switched to mouse fallback."
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



### Core methods ###
gaze.fn = gaze.prototype = {
    ### Initializes object and connects to an eye tracker ###
    init: (@url) -> 
        if @_initialized then deinit()

        # We should also call init() of our submodules here ... 
        # TODO: order by dependencies!!!
        console.log("Extensions are not sorted by dependencies at the moment, this will cause bugs...")
        for id, module of extensions
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



    ### Informs registered listeners about a problem ###
    problem: (id) -> @_onproblem.invoke problems[id]

    ### Register handler called when there was a problem ### 
    onproblem: (handler) -> @_onproblem.add handler

    ### Deinitializes this object, can be used again afterwards. ###
    deinit: () ->       
        for id, module of extensions
            if module.deinit then module.deinit @, module

        @_initialized = false

    ### Returns a new handlers object that can be used internally ###
    handlers: () -> new handlers()

    ### Sets the desired frame rate ###
    fps: (fps) ->

    ### Adds a listener that is called when the frame configuration
    in the tracker changed (e.g., new channels offered, old channels 
    removed) ###
    onframeconfig: (handler) -> @_onframeconfig.add handler

    ### Pushes a frame to all registered listeners or retrieves the currently 
    pushed frame. ###
    frame: (frame) -> 
        if frame
            @_currentframe = frame
            @_onframe.invoke frame
        else @_currentframe

    ### Registers for a frame ###
    onframe: (handler) -> @_onframe.add handler

    ### Returns the version ###
    version: () -> VERSION

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

    ### Returns the distance of a point and a rect or two points ###
    distance: (px, py, x, y, w, h) ->
      # TODO: Return actual distance if outside
      if px >= x && px <= x + w && py >= y && py <= y + h then return 0
      return 1        
}



### WATCHDOG ###
gaze.extension({} , { 
    id: "watchdog"
    init: (gaze) ->     
        time = Date.now()

        gaze.onframe () ->
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


    ### Converts a screen pixel position to a window position ###
    screen2window: (x, y) ->
        return [x, y]        
}, {
    id: "browser"

    problems: {
        "W_ZOOMRATIO": {
            message: "Unable to determine browser zoom ratio. Your results may be wrong. Try 
            zooming to 100% and hope for the best (and use another browser)."
            type: "warning"
        }
    }

    browser: "unknown"
    desktopzoom: 1.0
    windowoffsetx: 0
    windowoffsety: 0

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

      @windowoffsetx = dx
      @windowoffsety = dy

      localStorage.setItem("_gaze_windowoffsetx", dx)
      localStorage.setItem("_gaze_windowoffsety", dy)


    deinit: (gaze, module) -> global.document.removeEventListener @click

    init: (gaze, module) ->
        module._gaze = gaze

        # Compute some values and get others from localstorage
        module.browser = gaze.browser()
        module.desktopzoom = parseFloat(localStorage.getItem("_gaze_desktopzoom")) or 1.0
        module.windowoffsetx = parseInt(localStorage.getItem("_gaze_windowoffsetx")) or 0
        module.windowoffsety = parseInt(localStorage.getItem("_gaze_windowoffsety")) or 0

        # Checks if we have a screen info in the frame
        gaze.onframe (frame) ->
            if not frame.screen then return
            if not frame.screen.scaletologic then return

            module.desktopzoom = 1.0 / frame.screen.scaletologic

            # Not sure if we should save that often ...
            localStorage.setItem("_gaze_desktopzoom", module.desktopzoom) 


        global.document.addEventListener 'click', @click.bind(@)

        # Sets the appropriate screen2window function based on browser
        if module.browser == "chrome"            
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX + module.windowoffsetx) / p
                wy = (y - global.screenY + module.windowoffsety) / p
                return [wx, wy]

        if module.browser == "ie"
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX * p + module.windowoffsetx) / p
                wy = (y - global.screenY * p + module.windowoffsety) / p
                return [wx, wy]

        if module.browser == "safari" #TODO: safari currently wrong, measure again
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX + module.windowoffsetx) / p
                wy = (y - global.screenY + module.windowoffsety) / p
                return [wx, wy]

        if module.browser == "firefox"
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX * p + module.windowoffsetx) / p
                wy = (y - global.screenY * p + module.windowoffsety) / p
                return [wx, wy]

})



### RAW ###
gaze.extension({

    ### Adds a raw listener and returns a removal handle ###
    onraw: (listener) ->
        ext = @extension("raw") 
        return ext._handlers.add listener
}, {
    id: "raw"

    ### Initialize this module ###
    init: (gaze, module) ->     
        module._handlers = gaze.handlers()
        removal = null

        # Called when the first raw handler was added
        module._handlers.onpopulated = () ->
            removal = gaze.onframe (packet) ->
                module._handlers.invoke packet.raw

        # Called when the last raw handler was removed
        module._handlers.onempty = () ->
            removal.remove()
})




### FILTERED ###
gaze.extension({

    ### Adds a filtered listener and returns a removal handle ###
    onfiltered: (listener) ->
        ext = @extension("filtered") 
        return ext._handlers.add listener

    filter: (filter) ->
        ext = @extension("filtered")      

}, {
    id: "filtered"
    depends: ["raw", "browser"]    

    ### Initialize this module ###
    init: (gaze, module) -> 
        module._handlers = gaze.handlers()
        removal = null

        # TODO 
        # Register for frame config changes ... 
        gaze.onframeconfig (config) ->
            if provides_filtered
                listen_to_frame
                just_pass_along_filtered

            else
                register_raw
                filter_ourself
                send_our_data

        # Called when the first raw handler was added
        module._handlers.onpopulated = () ->
            removal = gaze.onframe (packet) ->
                module._handlers.invoke packet.raw

        # Called when the last raw handler was removed
        module._handlers.onempty = () ->
            removal.remove()
})




### DWELL ###
gaze.extension({
    ondwell: (elements, listener, options) ->
        ext = @extension("dwell")   

        if typeof elements == "string"
            elements = @_document.querySelectorAll elements


}, {
    id: "dwell" 
    depends: ["filtered", "watchdog"]    
    handlers: null

    init: (gaze) -> 
        @handlers = gaze.handlers()

        point = (pt) ->
            work_with_point()


        # 3 (x) ->
        # gaze.onfiltered (x) ->
        # gaze.onfixation (x) ->
})




### Connectors we use as backends ###
gaze.connectors = {
    "relay": (url, status, frame) -> 
        url = "ws://127.0.0.1:44042" if not url?

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
        }

    "mouse": (url, status, frame) ->      
        last = null

        motion = (e) -> last = e        
        tick = () ->

            if last
                x = last.clientX
                y = last.clientY

            frame {
                filtered: {
                    windowX: x
                    windowY: y
                }                
            }

        document.addEventListener('mousemove', motion, false);        
        setInterval tick, 30

        return {
            tracker: null
            type: "mouse"
            frameinfo: {
                filtered: {
                    
                }
            }
        }        
}


### Set global object ###
global.gaze = new gaze(global)
global.gaze.connectors = gaze.connectors





