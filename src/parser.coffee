{EventEmitter} = require 'events'
Header = require './header'
fs = require 'fs'

iconv = require 'iconv-lite'
iconv.skipDecodeWarning = true
stream = require 'stream'

class Parser extends EventEmitter

    constructor: (@filename, @encoding = 'utf-8') ->

    parse: =>
        @emit 'start', @

        if @filename instanceof stream.Stream
            stream = @filename
        else
            stream = fs.createReadStream @filename

        stream.once 'end', () =>
            @emit 'end'

        @header = new Header stream
        @header.parse (err) =>
            @emit 'header', @header

            sequenceNumber = 0
            
            @readBuf = =>
                if @paused

                    @emit 'paused'
                    
                    return
                while !@done and (buffer = stream.read @header.recordLength)
                    if buffer[0] == 0x1A
                        @done = true
                    else if buffer.length == @header.recordLength
                        @emit 'record', @parseRecord ++sequenceNumber, buffer

            stream.on 'readable',@readBuf

            do @readBuf

            return @

        return @
    
    parseRecord: (sequenceNumber, buffer) =>
        record = {
            '@sequenceNumber': sequenceNumber
            '@deleted': (buffer.slice 0, 1)[0] isnt 32
        }

        loc = 1
        for field in @header.fields
            do (field) =>
                record[field.name] = @parseField field, buffer.slice loc, loc += field.length

        return record

    parseField: (field, buffer) =>
        value = (iconv.decode buffer, @encoding).trim()

        if field.type is 'N' then value = parseFloat value

        return value

     pause: =>
        
        @paused = true
        
    resume: =>
    
        @paused = false

        @emit 'resuming'
        
        do @readBuf

module.exports = Parser
