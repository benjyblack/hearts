game = require('./game')
und = require('underscore')
_ = require('lodash')

infinity = 99999999

defensiveThreshold = 1
offensiveThreshold = 1

maxDepth = 4

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

  validCards

nextPlayer = (trick) ->
  currentPlayer = trick.round.game.info.position

  return 'east' if currentPlayer is 'north'
  return 'south' if currentPlayer is 'east'
  return 'west' if currentPlayer is 'south'
  return 'north' if currentPlayer is 'west'

heuristicValueOf = (trick) ->
  thisGame = trick.round.game
  player = thisGame.info.position

  result = game.resultOfTrick trick

  return -result.points if result.winner is player

  return 0

makeMove = (trick, card) ->
  copiedTrick = _.cloneDeep(trick)

  copiedTrick.played.push card

  copiedTrick

getChildrenOf = (trick) ->
  console.log "Getting children"
  children = []

  # get the trick as the next player sees it
  nextTrick = game.getOpponentsTrick nextPlayer trick

  # if nextTrick is -1 then the next trick belongs to the human player and we don't know his cards
  if not(nextTrick is -1)
    # get all of his possible moves and add them to the children
    for card in playableCards nextTrick
      children.push makeMove trick, card

  # return the children
  children

maxN = (trick, depth) ->
  console.log "Running maxN"
  # get children
  children = getChildrenOf trick

  # if we've reached the top of the tree, return the value of the trick
  if depth <= 0
    return heuristicValueOf(trick)
  else
    # assume everyone will maximize their value
    val = -infinity
    val = Math.max(val, paranoid(child, depth-1)) for child in children
  
    val


paranoid = (trick, depth) ->
  console.log "Running paranoid"
  # get children
  children = getChildrenOf trick

  # if we've reached the top of the tree, return the value of the trick
  if depth <= 0
    return heuristicValueOf(trick)
  else
    # maximize our value on our turn
    if depth % 4 is 0
      val = -infinity
      val = Math.max(val, paranoid(child, depth-1)) for child in children
    # otherwise, assume other players will minimize our value
    else
      val = infinity
      val = Math.min(val, paranoid(child, depth-1)) for child in children
    val

offensive = (trick, depth) ->
  console.log "Running offensive"
  # get children
  children = getChildrenOf trick

  # if we've reached the top of the tree, return the value of the trick
  if depth <= 0
    return heuristicValueOf(trick)
  else
    # minimize target player's value on our turn
    if depth % 4 is 0
      val = infinity
      val = Math.min(val, paranoid(child, depth-1)) for child in children
    # assume every other player will maximize their value
    else
      val = -infinity
      val = Math.max(val, paranoid(child, depth-1)) for child in children
    val

mpMix = (trick) ->
  console.log "Running MP-Mix"
  thisGame = trick.round.game
  me = thisGame.info.position

  # sort players in decreasing order
  sortable = []
  for key of thisGame.score
    sortable.push([key, thisGame.score[key]])
  sortable.sort (a, b) -> 
    a[1] - b[1]

  # find top two players
  firstPlacePlayer = sortable[0]
  secondPlacePlayer = sortable[1]

  # find leading edge
  leadingEdge = Math.abs(firstPlacePlayer[1] - secondPlacePlayer[1])
  trick.log "Leading edge:", leadingEdge
  
  if firstPlacePlayer[0] is me
    if leadingEdge >= defensiveThreshold
      val = paranoid trick maxDepth
      return
  else
    if leadingEdge >= offensiveThreshold
      val = offensive trick maxDepth
      return
  # maxN

doPassCards = (round) ->
  cardsToPass = round.dealt[0..2]

  cardsToPass

doPlayCard = (trick) ->
  mpMix(trick)

  trick.log "Current trick:", trick.played
  cardToPlay = playableCards(trick)[0]
  trick.log "Playing card:", cardToPlay

  cardToPlay

game.play(doPassCards, doPlayCard)

