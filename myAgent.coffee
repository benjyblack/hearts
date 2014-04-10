game = require('./game')
und = require('underscore')

defensiveThreshold = 1
offensiveThreshold = 1

directionsEnum = 
  north: 1
  east: 2
  south: 3
  west: 4

score = 
  north: 0
  east: 0
  south: 0
  west: 0

isLeadingTrick = (trick) ->
  trick.played.length == 0

isHeartsBroken = (trick)  ->
  trick.round.tricks.some((trick) -> trick.played.some((card) -> card.suit == game.Suit.HEARTS))

onlyTwoClubs = (cards) ->
  und.select(cards, (card) -> card.suit == game.Suit.CLUBS && card.rank == game.Rank.TWO)

noHearts = (cards) ->
  und.reject(cards, (card) -> card.suit == game.Suit.HEARTS)

noPoints = (cards) ->
  und.reject(noHearts(cards), (card) -> card.suit == game.Suit.SPADES && card.rank == game.Rank.QUEEN)

followSuit = (cards, trick) ->
  suit = trick.played[0].suit
  matching = und.filter(cards, (card) -> card.suit == suit)
  if matching.length > 0
    matching
  else
    cards

playableCards = (trick) ->
  validCards = trick.round.held.slice(0)

  validCards = onlyTwoClubs(validCards) if trick.number == 1 && isLeadingTrick(trick)
  validCards = noPoints(validCards) if trick.number == 1
  validCards = noHearts(validCards) if isLeadingTrick(trick) && !isHeartsBroken(trick) && noHearts(trick.round.held).length > 0
  validCards = followSuit(validCards, trick) if !isLeadingTrick(trick)

  trick.log "Valid cards:", validCards
  validCards

doPassCards = (round) ->
  cardsToPass = round.dealt[0..2]
  round.log "Passing cards", cardsToPass

  cardsToPass

doPlayCard = (trick) ->
  thisGame = trick.round.game
  me = thisGame.info.position
  
  # evaluate each player
  
  # find two top players
  sortable = []
  for key of thisGame.score
    sortable.push([key, thisGame.score[key]])
  sortable.sort (a, b) -> 
    a[1] - b[1]

  firstPlacePlayer = sortable[0]
  secondPlacePlayer = sortable[1]

  # find leading edge
  leadingEdge = Math.abs(firstPlacePlayer[1] - secondPlacePlayer[1])
  trick.log "Leading edge:", leadingEdge
  
  if firstPlacePlayer[0] is me
    if leadingEdge >= defensiveThreshold
      # paranoid
      return
  else
    if leadingEdge >= offensiveThreshold
      # offensive
      return
  # maxN

  trick.log "Current trick:", trick.played
  cardToPlay = playableCards(trick)[0]
  trick.log "Playing card:", cardToPlay

  cardToPlay

game.play(doPassCards, doPlayCard)

