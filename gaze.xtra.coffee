###

gaze.xtra.js

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


###

This file contains additional modules and libraries that are highly
experimental / subject to change / unsupported.

###





### READING ###
gaze.extension({
    ### Adds a filtered listener and returns a removal handle ###
    onreading: (listener) ->
        ext = @extension("reading")
        ext._handlers.add listener
} , {
    id: "reading"

    ### Initialize this module ###
    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        removal = null

        lastfixations = []

        func = (fixation) ->
            # In case we don't have the focus, we don't do anything
            if not gaze.isactive() then return

            lastfixations.push fixation

            # Maintain window of a certain size, dont act before that ...
            if lastfixations.length > 6
                lastfixations.shift()
            else return


            sum = [0, 0]

            # Compute features (angularity & forward speed)
            for f, i in lastfixations
                if i == 0 then continue
                flast = lastfixations[i-1]

                sum[0] += Math.abs(f.screenX - flast.screenX)
                sum[1] += Math.abs(f.screenY - flast.screenY)

            angularity = Math.atan2(sum[1], sum[0])


            # Compute forward speed
            deltas = []

            for f, i in lastfixations
                if i == 0 then continue
                flast = lastfixations[i-1]

                delta = []
                delta[0] = f.screenX - flast.screenX
                delta[1] = f.screenY - flast.screenY

                angle = Math.atan2(delta[1], delta[0])
                if Math.abs(angle) < Math.PI / 3
                    deltas.push delta

            sum = [0, 0]

            for delta in deltas
                sum[0] += delta[0]
                sum[1] += delta[1]

            if deltas.length > 0
                sum[0] /= (deltas.length * 10) # TODO: Replace w. virtual character size
                sum[1] /= (deltas.length * 10) # TODO: Replace w. virtual character size

            speed = Math.sqrt( sum[0]**2 + sum[1]**2 )

            cls = -2.97 + 5.36 * angularity + 0.17 * speed

            module._handlers.invoke {
                angularity: angularity
                speed: speed
                classification: cls
            }

        # Called when the first handler was added or removed
        module._handlers.onpopulated = () ->
            removal = gaze.onfixation func
            lastfixations = []

        module._handlers.onempty = () -> removal.remove()
})
