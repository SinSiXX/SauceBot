# SauceBot Data Transfer Object


db = require './saucedb'
io = require './ioutil'

# Data Transfer Object abstract base class
class DTO
    constructor: (@channel, @table) ->
        # Constructs the DTO
        
    load: ->
        # Loads data from the database
        
    add: (item) ->
        # Adds item to the database
        
    remove: (item) ->
        # Removes item from the database
        
    clear: ->
        # Clears all items from the database
        
    set: (items) ->
        # Set database items
        
    get: ->
        # Returns the underlying dataset
        

# Data Transfer Object for arrays
class ArrayDTO extends DTO
    constructor: (channel, table, @valueField) ->
        super channel, table
        @data = []
        
        
    load: ->
        db.loadData @channel.id, @table, @valueField, (data) =>
            @data = data
            io.module "Updated #{@table} for #{@channel.id}:#{@channel.name}"
        
    
    save: ->
        db.setChanData @channel.id, @table, [@valueFields], [@data] 
    
     
    add: (item) ->
         
         # XXX: This will "fail" when the item is in @data, only with
         #      a different case. I'll fix it later. Maybe.
         return if item in @data
         
         @data.push item
         db.addChanData @channel.id, @table, [@valueField], [[item]]
        
         
    remove: (item) ->
        @data = (elem for elem in @data when not equalsIgnoreCase item, elem)
        db.removeChanData @channel.id, @table, @valueField, item
        
    
    clear: ->
        @data = []
        db.clearChanData @channel.id, @table
        
    
    set: (items) ->
        @data = items
        @save()
        
        
    get: ->
        @data
     
     
     
# Data Transfer Object for hashes
class HashDTO extends DTO
    constructor: (channel, table, @keyField, @valueField) ->
        super channel, table
        @data = {}
    
    
    # Loads the database data into the underlying hash
    load: ->
        db.loadData @channel.id, @table, 
                key: @keyField
                value: @valueField
            , (data) =>
                @data = data
                io.module "Updated #{@table} for #{@channel.id}:#{@channel.name}"

    
    # Saves the data to the database
    save: ->
        dataList = ([key, value] for key, value of @data)
        db.setChanData @channel.id, @table, [@keyField, @valueField], dataList

    
    # Adds a (key, value)-pair to the database
    add: (key, value) ->
        @data[key] = value
        db.addChanData @channel.id, @table, [@keyField, @valueField], [[key, value]]
        
    
    # Removes a row from the database
    remove: (key) ->
        delete @data[key]
        db.removeChanData @channel.id, @table, @keyField, key
        
   
    # Clears the database data
    clear: ->
        @data = {}
        db.clearChanData @channel.id, @table
        

    # Sets the hash data
    set: (items) ->
        @data = items
        @save()
        
    
    # Returns the underlying hash, or the specified element.
    # Be sure to call HashDTO.save() if you have modified it.
    get: (key) ->
        if key? then @data[key] else @data 
        
    
# Data Transfer Object for "single-row" tables, i.e. config tables.
class ConfigDTO extends DTO
    constructor: (channel, table, @fields) ->
        super channel, table
        @data = {}
        @data[field] = 0 for field in @fields
            
            
    load: ->
        db.getChanDataEach @channel.id, @table, (data) =>
            @data = data


    save: ->
        db.setChanData @channel.id, @table,
                (field for field in @fields),
                [(@data[field] for field in @fields)]
        

    add: (field, value) ->
        return unless field in @fields
        
        @data[field] = value
        @save()
        value
    
        
    remove: (field) ->
        return unless field in @fields
        
        value = 0
        @data[field] = value
        @save()
        value
        
    
    clear: ->
        @data[field] = 0 for field in @fields
        @save()
        
        
    set: (items) ->
        throw new Error "Can't set ConfigDTO"
    
    
    get: (field) ->
        if field? then @data[field] else @data
    
    
# HashDTO for id-based tables
class EnumDTO extends HashDTO
        getNewID: ->
            id = 0
            for key of @data
                if `key == id` then id++
            id
     
     
        add: (value) ->
            super @getNewID(), value
        
        
        get: ->
            (value for key, value of @data)
            
    

    
    
equalsIgnoreCase = (a, b) ->
    a.toLowerCase() is b.toLowerCase()



exports.ArrayDTO = ArrayDTO
exports.HashDTO  = HashDTO
exports.ConfigDTO = ConfigDTO
exports.EnumDTO  = EnumDTO