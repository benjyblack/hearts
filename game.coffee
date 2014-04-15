thrift = require('thrift')
Hearts = require('./lib/Hearts')
types = require('./lib/hearts_types')
und = require('underscore')
_ = require('lodash')

games = []

directionToNum = 
  north : 0
  east : 1
  south : 2
  west : 3

numToDirection =
  0 : "north"
  1 : "east"
  2 : "south"
  3 : "west"

resultOfTrick = (trick) ->
  # get lead suit
  suit = trick.played[0].suit
  leaderAsNum = directionToNum[trick.leader]

  # get who won and tally up all the points
  highestCard = trick.played[0]
  winningDirectionAsNum = leaderAsNum
  pointsForTrick = 0

  for card, i in trick.played
    pointsForTrick++ if card.suit is types.Suit.HEARTS
    pointsForTrick += 13 if card.suit is types.Suit.SPADES and card.rank is types.Rank.QUEEN

    if card.rank > highestCard.rank and card.suit is suit
      highestCard = card
      winningDirectionAsNum = (i + leaderAsNum) % 4;

  winnerAsDirection = numToDirection[winningDirectionAsNum]

  return {
    winner: winnerAsDirection
    points: pointsForTrick
  }

class Trick
  constructor: (@number, @round, @options) ->
    @leader = null
    @played = []

  run: (callback) ->
    @log "Starting trick"
    @options.client.get_trick @options.ticket, (err, trick) =>
      throw err if err
      @leader = trick.leader
      @played = trick.played

      cardToPlay = @options.playCardFn this
      @round.held.splice(@round.held.indexOf(cardToPlay), 1)
      @options.client.play_card @options.ticket, cardToPlay, (err, trickResult) =>
        throw err if err
        @log "trick: result", trickResult
        @played = trickResult.played

        # update the game's score
        @round.game.updateScore trickResult
        @log "trick: new score", @round.game.score

        callback()

  log: (args...) ->
    @round.log "T:#{@number}", args...

class Round
  constructor: (@number, @game, @options) ->
    @tricks = []
    @dealt = []
    @passed = []
    @received = []
    @held = []

  createTrick: ->
    trickNumber = @tricks.length + 1
    trick = new Trick(trickNumber, this, @options)
    @tricks.push trick
    trick

  run: (callback) ->
    @log "Starting round"
    @options.client.get_hand @options.ticket, (err, hand) =>
      throw err if err
      @log "You were dealt:", hand
      @dealt = hand.slice(0)
      @held = hand.slice(0)

      @passCards =>
        @playTrick callback

  passCards: (callback) ->
    if @number % 4 == 0
      @log "Not passing cards"
      callback()
    else
      @log "About to pass cards"
      @passed = @options.passCardsFn this
      for cardToPass in @passed
        @held.splice(@held.indexOf(cardToPass), 1)

      @options.client.pass_cards @options.ticket, @passed, (err, receivedCards) =>
        throw err if err
        @received = receivedCards
        @log "Received cards:", @received
        @held = @held.concat(@received)
        callback()

  playTrick: (callback) ->
    trick = @createTrick()

    trick.run =>
      if @tricks.length >= 13
        callback()
      else
        @playTrick(callback)

  log: (args...) ->
    @game.log "R:#{@number}", args...

class Game
  constructor: (@info, @options) ->
    @rounds = []
    @score = 
      north: 0
      east: 0
      south: 0
      west: 0

  createRound: ->
    roundNumber = @rounds.length + 1
    round = new Round(roundNumber, this, @options)
    @rounds.push round
    round

  run: (callback) ->
    @log "Starting game"

    round = @createRound()

    round.run =>
      @options.client.get_round_result @options.ticket, (err, roundResult) =>
        throw err if err
        @log "round result:", roundResult
        if roundResult.status != types.GameStatus.NEXT_ROUND
          callback()
        else
          @run(callback)

  updateScore: (trick) ->
    result = resultOfTrick trick

    # allocate points
    @score[trick.winner] += trick.points
    
    @score

  log: (args...) ->
    console.log "P:#{@info.position}", args...

exports.play = (passCardsFn, playCardFn) ->
  host = process.env.AVA_HOST || '127.0.0.1'
  port = process.env.AVA_PORT || 4001
  
  for i in [1..3]
    transport = thrift.TFramedTransport
    connection = thrift.createConnection(host, port, {transport: transport})
    client = thrift.createClient(Hearts, connection)

    request = new types.EntryRequest()
    console.log "Entering arena", request
    client.enter_arena request, (err, response) =>
      throw err if err
      ticket = response.ticket
      if ticket
        console.log "playing"
        client.get_game_info ticket, (err, gameInfo) =>
          throw err if err
          console.log "game info:", gameInfo

          game = new Game gameInfo,
            ticket: ticket
            client: client
            passCardsFn: passCardsFn
            playCardFn: playCardFn

          games.push game

          game.run =>
            console.log "Game is over"
            client.get_game_result ticket, (err, gameResult) ->
              throw err if err
              console.log "game result:", gameResult
              connection.end()
      else
        console.log "No ticket"
        connection.end()

exports.getOpponentsTrick = (opponent) =>
  for game in games
    numRounds = game.rounds.length-1
    numTricksInRound = game.rounds[numRounds].tricks.length-1
    return _.cloneDeep(game.rounds[numRounds].tricks[numTricksInRound]) if game.info.position is opponent

  return -1

exports.numToDirection = numToDirection

exports.directionToNum = directionToNum

exports.resultOfTrick = resultOfTrick; 

exports.Suit = types.Suit
exports.Rank = types.Rank
exports.Card = types.Card