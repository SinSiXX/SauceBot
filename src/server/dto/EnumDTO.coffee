# SauceBot Data Transfer Object


db = require '../saucedb'
io = require '../ioutil'
{HashDTO} = require './HashDTO'
    
# HashDTO for id-based tables
#
# An EnumDTO is basically a HashDTO, except that the key to each value is
# incremented to add a new value.
class EnumDTO extends HashDTO
        getNewID: ->
            # This bit works, but it relies on the iteration over @data to be
            # in ascending order; otherwise, duplicate IDs could be generated,
            # and all hell would break loose
            id = 0
            for key of @data
                if key == id then id++
            id
     
     
        add: (value) ->
            super @getNewID(), value
        
        
        get: ->
            (value for key, value of @data)
            
   

exports.EnumDTO = EnumDTO