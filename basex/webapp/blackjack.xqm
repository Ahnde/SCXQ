
module namespace bj='https://www.blackjackinfo.com/blackjack-rules/';

import module namespace scxq='http://www.w3.org/2005/07/scxml' at 'scxml-interpreter.xqm';

(:
  Create the databases, which are needed for the Blackjack game.
:)
declare
  updating function bj:setup()
{
  bj:createDatabases()
};

(:
  Create the databases, which are needed for the SCXML-interpreter.
:)
declare
  updating function bj:initialize()
{
  let $initialConfig := bj:_createBlackjackConfig()
  return bj:_setConfig($initialConfig)
};

(:
  Create the databases, which are needed for the SCXML-interpreter.
:)
declare
  function bj:showGameState()
{
  let $viewModel := bj:_createViewModel()
  return $viewModel
};

(:
  Create the databases, which are needed for the SCXML-interpreter.
:)
declare
  updating function bj:addPlayer($amountOfMoney)
{
  let $blackjackConfig := bj:_getCurrentConfig()
  let $playerId := $blackjackConfig/blackjackConfig/idForNewPlayer/text()
  let $newIdForNewPlayer := $playerId + 1

  let $players := bj:_getPlayers()
  let $oldPlayerCount := bj:_getPlayerCount()
  let $newPlayerCount := $oldPlayerCount + 1
  let $newPlayer := bj:_createPlayer($playerId, $amountOfMoney)
  return 
    (
      if ($oldPlayerCount = 0) then bj:_setPlayerId($playerId) else (),
      replace value of node $oldPlayerCount with $newPlayerCount,
      insert node $newPlayer into $players,
      replace value of node $blackjackConfig/blackjackConfig/idForNewPlayer with $newIdForNewPlayer
    )
};

(:
  Removes the player with a given ID.
:)
declare
  updating function bj:removePlayer($playerId)
{
  let $currentPlayerId := string(bj:_getCurrentPlayerId()/text())
  let $removedCurrentPlayer := $currentPlayerId = $playerId
  let $players := bj:_getPlayers()
  let $oldPlayerCount := bj:_getPlayerCount()
  let $newPlayerCount := 
    if ($oldPlayerCount = 0) then
      0
    else
      $oldPlayerCount - 1
  return 
    (
      if ($removedCurrentPlayer) then bj:_setCurrentPlayerIdSinceCurrentPlayerWasRemoved($oldPlayerCount) else (),
      replace value of node $oldPlayerCount with $newPlayerCount,
      delete node $players/player[@id=$playerId]
    )
};

(:
  Triggers the next turn of the game.
:)
declare
  updating function bj:newTurn()
{
  (
    bj:_clearHands(),
    bj:_setNextPlayerToInitialPlayer(),
    scxq:receiveEvent('newTurn')
  )
};

(:
  Triggers bidding a given amount of money for the current player.
:)
declare
  updating function bj:bid($amount)
{
  let $currentPlayer := bj:_getCurrentPlayer()
  let $currentMoney := $currentPlayer/money/text()
  let $newMoney := $currentMoney - $amount
  return  (
            replace value of node $currentPlayer/bid with $amount,
            replace value of node $currentPlayer/money with $newMoney,
            bj:_setNextPlayer()
          )
};

(:
  Triggers drawing a cards for the current player.
:)
declare
  updating function bj:hit()
{
  let $newCard := bj:_getNewCard()
  let $currentPlayer := bj:_getCurrentPlayer()
  let $currentValue := $currentPlayer/hand/value/text()
  let $newValue := $currentValue + number(string($newCard/@value))
  return  (
            replace value of node $currentPlayer/hand/value with $newValue,
            insert node $newCard into $currentPlayer/hand/cards
          )
};

(:
  Triggers setting the next player, since the current player decided to not draw any more cards.
:)
declare
  updating function bj:stand()
{
  (
    bj:_setNextPlayer(),
    scxq:receiveEvent('stand')
  )
};

(:
  Handler for the events of the SCXML.
:)
declare
  updating function bj:eventFromScxml($event)
{
  if ($event = 'showInitialCards') then
    bj:_drawInitialCards()
  else if ($event = 'showResult') then
    bj:_updateHandForBank()
  else if ($event = 'payOut') then
    bj:_updateMoneyForResult()
  else if ($event = 'end') then
    ()
  else
    ()
};

(:
  Triggers setting the next player.
:)
declare
  updating function bj:_setNextPlayer()
{
  let $currentPlayerId := bj:_getCurrentPlayerId()
  let $players := bj:_getPlayers()
  let $nextPlayer := $players//player[@id=$currentPlayerId]/following-sibling::player[1]
  return
    if (empty($nextPlayer)) then
      bj:_setNextPlayerToInitialPlayer()
    else
      bj:_setPlayerId(string($nextPlayer/@id))
};

(:
  Set the next player to the first player, since all players already did their turn.
:)
declare
  updating function bj:_setNextPlayerToInitialPlayer()
{
  let $players := bj:_getPlayers()
  let $newPlayerId := string($players/player[1]/@id)
  return bj:_setPlayerId($newPlayerId)
};

(:
  Sets the current player to a different player, after the current player was removed from the game.
:)
declare
  updating function bj:_setCurrentPlayerIdSinceCurrentPlayerWasRemoved($playerCount)
{
  if ($playerCount = 0 or $playerCount = 1) then
    bj:_setPlayerId(())
  else
    bj:_setNextPlayer()
};

(:
  Sets the player ID for the current player.
:)
declare
  updating function bj:_setPlayerId($newPlayerId)
{
  let $currentPlayerId := bj:_getCurrentPlayerId()
  return replace value of node $currentPlayerId with $newPlayerId
};

(:
  Triggers the clearing of the hand for the bank and all players.
:)
declare
  updating function bj:_clearHands()
{
  (
    bj:_clearHandForBank(),
    bj:_clearHandsForPlayers()
  )
};

(:
  Removes all cards from the hand of the bank.
:)
declare
  updating function bj:_clearHandForBank()
{
  let $bank := bj:_getBank()
  return  
    (
      replace value of node $bank/hand/cards with <cards/>,
      replace value of node $bank/hand/value with 0
    )
};

(:
  Removes all cards from all players hands.
:)
declare
  updating function bj:_clearHandsForPlayers()
{
  let $players := bj:_getPlayers()
  let $playerNodes := $players/*
  for $player in $playerNodes
    return  
      (
        replace value of node $player/hand/cards with <cards/>,
        replace value of node $player/hand/value with 0
      )
};

(:
  Triggers the drawing of the initial cards for the bank and all players.
:)
declare
  updating function bj:_drawInitialCards()
{
  (
    bj:_drawInitialCardsForBank(),
    bj:_drawInitialCardsForPlayers()
  )
};

(:
  Draws the initial card for the bank, and updates the database.
:)
declare
  updating function bj:_drawInitialCardsForBank()
{
  let $bank := bj:_getBank()
  let $card := bj:_getNewCard()
  let $value := number(string($card/@value))
  return  
    (
      replace value of node $bank/hand/value with $value,
      insert node $card into $bank/hand/cards
    )
};

(:
  Draws the initial card for each player, and updates the database.
:)
declare
  updating function bj:_drawInitialCardsForPlayers()
{
  let $players := bj:_getPlayers()
  let $playerNodes := $players/*
  for $player in $playerNodes
    let $firstCard := bj:_getNewCard()
    let $secondCard := bj:_getNewCard()
    let $value := number(string($firstCard/@value)) + number(string($secondCard/@value))
    return  
      (
        replace value of node $player/hand/value with $value,
        insert node $firstCard into $player/hand/cards,
        insert node $secondCard into $player/hand/cards
      )
};

(:
  Updates the cards of the bank, after all players are done drawing cards.
:)
declare
  updating function bj:_updateHandForBank()
{
  let $bank := bj:_getBank()
  let $recentCards := $bank/hand/cards/*
  let $bankCardsSequence := bj:_drawForBank($recentCards)
  let $bankValue := bj:_valueForCardsSequence($bankCardsSequence)
  let $bankCards := <cards>{$bankCardsSequence}</cards>
  return  
    (
      replace value of node $bank/hand/value with $bankValue,
      replace node $bank/hand/cards with $bankCards
    )
};

(:
  Draws the hand of cards for the bank.
:)
declare
  function bj:_drawForBank($currentCardsSequence)
{
  let $currentValue := bj:_valueForCardsSequence($currentCardsSequence)
  let $newCardsSequence :=
    if ($currentValue < 17) then
      let $newCard := bj:_getNewCard()
      return bj:_drawForBank(insert-before($currentCardsSequence, 10, $newCard))
    else
      $currentCardsSequence
  return $newCardsSequence
};

(:
  Updated the current money amount of all players, depending if they won or lost.
:)
declare
  updating function bj:_updateMoneyForResult()
{
  for $player in bj:_getPlayers()/*
    let $playerId := string($player/@id)
    let $winStatus := bj:_winStatusForPlayerWithId($playerId)
    let $newAmountOfMoney :=
      if ($winStatus = 'win') then
        let $winAmount := $player/bid/text() * 2
        return $player/money/text() + $winAmount
      else if ($winStatus = 'tie') then
        let $winAmount := $player/bid/text()
        return $player/money/text() + $winAmount
      else
        $player/money/text()
    return 
      (
        bj:_clearHands(),
        replace value of node $player/money with $newAmountOfMoney,
        replace value of node $player/bid with 0
      )
};

(:
  Returns the status, whether the player with a given ID did win, lose or tie the bank.
:)
declare
  function bj:_winStatusForPlayerWithId($playerId)
{
  let $bank := bj:_getBank()
  let $bankValue := $bank/hand/value/text()
  let $player := bj:_getPlayerForId($playerId)
  let $playerValue := $player/hand/value/text()
  let $winStatus :=
    if ($playerValue < 22) then
      if ($bankValue > 22 or $playerValue > $bankValue) then
        'win'
      else if ($playerValue = $bankValue) then
        'tie'
      else
        'lose'
    else
      'lose'
  return $winStatus
};

(:
  Returns the bank of the Blackjack game.
:)
declare
  function bj:_getBank()
{
  let $currentConfig := bj:_getCurrentConfig()
  let $bank := $currentConfig/blackjackConfig/bank
  return $bank
};

(:
  Returns the list of players, that are playing the game right now.
:)
declare
  function bj:_getPlayers()
{
  let $currentConfig := bj:_getCurrentConfig()
  let $players := $currentConfig/blackjackConfig/players
  return $players
};

(:
  Returns current player.
:)
declare
  function bj:_getCurrentPlayer()
{
  let $currentPlayerId := bj:_getCurrentPlayerId()
  let $currentPlayer := bj:_getPlayerForId($currentPlayerId)
  return $currentPlayer
};

(:
  Returns the player object for a given player ID.
:)
declare
  function bj:_getPlayerForId($id)
{
  let $currentPlayerId := bj:_getCurrentPlayerId()
  let $players := bj:_getPlayers()
  let $player := $players/player[@id=$currentPlayerId]
  return $player
};

(:
  Returns the ID of the current player.
:)
declare
  function bj:_getCurrentPlayerId()
{
  let $currentConfig := bj:_getCurrentConfig()
  let $currentPlayerId := $currentConfig/blackjackConfig/currentPlayerId
  return $currentPlayerId
};

(:
  Sets the current player.
:)
declare
  updating function bj:_setCurrentPlayerId($id)
{
  let $currentConfig := bj:_getCurrentConfig()
  return 
    (
      replace node $currentConfig/blackjackConfig/currentPlayerId with <currentPlayerId>{$id}</currentPlayerId>
    )
};

(:
  Returns the number of players, that are playing the game right now.
:)
declare
  function bj:_getPlayerCount()
{
  let $currentConfig := bj:_getCurrentConfig()
  let $playerCount := $currentConfig/blackjackConfig/playerCount/text()
  return $playerCount
};

(:  CARDS  :)

(:
  Returns the list of possible cards of the game.
:)
declare
  function bj:_getCards()
{
  let $cards := doc("./static/blackjack-cards.xml")
  return $cards
};

(:
  Create the databases, which are needed for the SCXML-interpreter.
:)
declare
  function bj:_setCards($cards)
{
  let $cards := doc("./static/blackjack-cards.xml")
  return $cards
};

(:
  Generates a new random Blackjack card.
:)
declare
  function bj:_getNewCard()
{
  let $randomNumber := random:integer(51) + 1
  let $cards := bj:_getCards()
  let $newCard := $cards/cards/card[@id=$randomNumber]
  return $newCard
};

(: 
  Returns the current Blackjack config.
:)
declare 
  function bj:_getCurrentConfig()
{
  let $config := db:open('blackjackConfig')
  return $config
};

(:Sets the current Blackjack config.
:)
declare
  updating function bj:_setConfig($config)
{
  db:replace('blackjackConfig', '/blackjack-config.xml', $config)
};

(: 
  Returns the accumulated value for all cards in a hand.
:)
declare
  function bj:_valueForCardsSequence($hand)
{
  let $values :=
    for $card in $hand
      let $value := number(string($card/@value))
      return $value
  return sum($values)
};

(: 
  Creates view model for the table, i.e. the current represtation of the gamestate.
:)
declare 
  function bj:_createViewModel()
{
  let $viewModel := 
    if (1) then
      let $currentStateId := scxq:getCurrentStateId()
      let $possibleEvents := scxq:getPossibleEvents()
      let $currentVariables := scxq:getCurrentVariables()
      let $table := bj:_createTableViewModel()
      return
        <xml>
          <scxmlInfo>
            <currentStateId>{$currentStateId}</currentStateId>
            <space/>
            <space/>
            {$possibleEvents}
            <space/>
            <space/>
            <variables>{$currentVariables}</variables>
          </scxmlInfo>
          <viewModel>
            {$table}
          </viewModel>
        </xml>
    else
      <viewModel/>
  return $viewModel
};

(: 
  Creates view model for the table, i.e. the current represtation of the gamestate.
:)
declare 
  function bj:_createTableViewModel()
{
  let $bank := bj:_getBank()
  let $currentPlayerId := bj:_getCurrentPlayerId()
  let $players := bj:_getPlayers()
  let $playerCount := bj:_getPlayerCount()
  return  
    <table>
      {$bank}
      <space/>
      {$currentPlayerId}
      <space/>
      {$players}
    </table>
};

(: 
  Creates the initial Blackjack config.
:)
declare 
  function bj:_createBlackjackConfig()
{
  <blackjackConfig>
    <bank>
      <hand>
        <value>0</value>
        <cards/>
      </hand>
    </bank>
    <idForNewPlayer>0</idForNewPlayer>
    <playerCount>0</playerCount>
    <currentPlayerId/>
    <players/>
  </blackjackConfig>
};

(: 
  Creates the new player with start budget as parameter.
:)
declare 
  function bj:_createPlayer($playerId, $money)
{
  let $player :=
    <player id="{$playerId}">
      <hand>
        <value>0</value>
        <cards/>
      </hand>
      <bid/>
      <money>{$money}</money>
    </player>
  return $player
};

(:
  Create the database, for the config of the Blackjack game.
:)
declare
  updating function bj:createDatabases()
{
  let $blackjackConfig := doc("./static/blackjack-config.xml")
  return db:create('blackjackConfig', $blackjackConfig, '/blackjack-config.xml')
};
