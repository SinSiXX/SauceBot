# SauceBot Module: Poll

Sauce = require '../sauce'
db    = require '../saucedb'
io    = require '../ioutil'

{HashDTO} = require '../dto'
{Module } = require '../module'

# Module description
exports.name        = 'Poll'
exports.version     = '1.0'
exports.description = 'Channel voting system'

exports.strings = {
    'err-usage'            : 'Usage: @1@'
    'err-no-poll-specified': 'No poll specified'
    'err-no-active-poll'   : 'No active poll. Start with @1@'
    'err-unknown-poll'     : 'Unknown poll. Create it with @1@'
    
    'action-started': '"@1@" started! Vote with @2@. Options: @3@'
    'action-created': '"@1@" created! Start with @2@'
    'action-results': '@1@ results: @2@'
}

io.module '[Poll] Init'

class Poll extends Module
    constructor: (@channel) ->
        super @channel
        @pollDTO = new HashDTO @channel, 'poll', 'name', 'options'
        
        @reset()

        
    load: ->
        @registerHandlers()
        
        @pollDTO.load =>
            @updatePollList()
            
        @regVar 'poll', (user, args, cb) =>
            return cb 'N/A' unless @activePoll?
            
            if not args[0] or args[0] is 'name'
               return cb @activePoll
            
            cb switch args[0]
                when 'options' then @polls[@activePoll]
                when 'votes'   then @hasVoted.length
                when 'results' then (if @activePoll? then @getResults() else 'N/A')
                else 'undefined'

        # Register web interface update handlers
        @regActs {
            # Poll.list()
            'list': (user, params, res) =>
                res.send @pollDTO.get()

            # Poll.active()
            'active': (user, params, res) =>
                unless @activePoll?
                    return res.error "No active poll"

                active = @polls[@activePoll]
                votes = {}
                votes[active[opt]] = num for opt, num of @votes
                res.send poll: @activePoll, votes: votes

            # Poll.start(name)
            'start': (user, params, res, bot) =>
                {name} = params
                unless @polls[name]?
                    return res.error "No such poll"

                @startPoll name, bot
                res.ok()

            # Poll.create(name, options, start?)
            'create': (user, params, res, bot) =>
                {name, options, start} = params

                @createPoll name, options
                @startPoll  name, bot     if start
                res.ok()

            # Poll.end()
            'end': (user, params, res, bot) =>
                unless @activePoll?
                    return res.error "No active poll"

                active = @polls[@activePoll]
                votes = {}
                votes[active[opt]] = num for opt, num of @votes
                res.send poll: @activePoll, votes: votes
                @endPoll bot
                
        }
                    

    updatePollList: ->
        @polls = {}
        for pollName, pollOptions of @pollDTO.get()
            @polls[pollName] = pollOptions.split /\s+/
            

    # Clears all votes and stops any active polls in this module. This is also
    # used for initialization of the module.   
    reset: ->
        @activePoll = null
        @hasVoted   = []
        @votes      = []


    registerHandlers: ->
        # !poll <name> [<opt1> <opt2> ...] - Starts/creates a new poll
        @regCmd 'poll'    , Sauce.Level.Mod, @cmdPollStart
        
        # !poll end - Ends the active poll
        @regCmd 'poll end', Sauce.Level.Mod, @cmdPollEnd
        
        # !vote <value> - Adds a vote to the current poll
        @regCmd 'vote'    , Sauce.Level.User, @cmdPollVote


    cmdPollStart: (user, args, bot) =>
        unless args[0]?
            return bot.say '[Poll] ' + @str('err-no-poll-specified') + '. ' + @str('err-usage', '!poll <name> <opt1> <opt2> ...')
            
        pollName = args.shift().toLowerCase()
        
        unless args.length
            unless @polls[pollName]?
                return bot.say '[Poll] ' + @str('err-unknown-poll', "!poll #{pollName} <opt1> <opt2> ...")
                
            @startPoll pollName, bot
        else
            @createPoll pollName, args.join(' '), bot
            

    # Starts a poll.
    # * pollName: The name of the poll.
    # * bot     : Optional bot object to send a confirmation message.
    startPoll: (pollName, bot) ->
        @reset()
        poll = @polls[pollName]
        @activePoll = pollName
        @votes = (0 for opt in poll)
        
        bot?.say '[Poll] ' + @str('action-started', pollName, '!vote <option>', poll.join ', ')


    # Creates a poll.
    # * pollName: The name of the poll.
    # * options : A space-separated list of options.
    # * bot     : Optional bot object to send a confirmation message.
    createPoll: (pollName, options, bot) ->
        @pollDTO.add pollName, options.toLowerCase()
        @updatePollList()

        bot?.say '[Poll] ' + @str('action-created', pollName, '!poll ' + pollName)


    # Ends the active poll.
    # * bot: Optional bot object to send a confirmation message.
    endPoll: (bot) ->
        bot?.say '[Poll] ' + @str('action-results', @activePoll, @getResults())
        @reset()

 
    cmdPollEnd: (user, args, bot) =>
        unless @activePoll?
            return bot.say '[Poll] ' + @str('err-no-active-poll', '!poll <name>')
            
        @endPoll bot

        
    getResults: ->
        # Take each key (option) in @votes, then sort these keys on their
        # values in @votes, then for each of these sorted keys, get the name of
        # the key and the corresponding vote count, and finally join it with
        # commas. That was easy.
        ("#{@polls[@activePoll][key]}: #{@getScore key}" for key in ((key for val, key in @votes).sort (a, b) =>
            @votes[b] - @votes[a])).join ', '
       
       
    getScore: (key) ->
        score = @votes[key]
        total = 0
        total += value for value, idx in @votes
        
        percentage = ~~((score * 100.0 / total)*10)/10
        "#{score} (#{percentage}%)"
       
        
    cmdPollVote: (user, args, bot) =>
        user = user.name
        return if !@activePoll? or user in @hasVoted

        if args[0]? and (idx = @polls[@activePoll].indexOf(args[0].toLowerCase())) isnt -1
            @hasVoted.push user
            @votes[idx]++

        
exports.New = (channel) -> new Poll channel
        
