
module namespace page='http://basex.org/modules/web-page';

import module namespace bj='https://www.blackjackinfo.com/blackjack-rules/' at 'blackjack.xqm';
import module namespace scxq='http://www.w3.org/2005/07/scxml' at 'scxml-interpreter.xqm';

(: ---------------------------- :)
(: --------- Rest API --------- :)
(: ---------------------------- :)

(:
  Initial call for initializing the databases of the SCXML interpeter and the Blackjack game.
:)
declare
  %rest:path("/setup")
  %rest:GET
  updating function page:setup()
{
  (
    page:updating_redirect('/initialize'),
    scxq:setup(),
    bj:setup()
  )
};

(:
  Call for filling the databases with clean configuration files.
:)
declare
  %rest:path("/initialize")
  %rest:GET
  updating function page:initialize()
{
  (
    page:updating_redirect('/blackjack/startGame'),
    scxq:initialize(),
    bj:initialize()
  )
};

(:
  Call for starting the game, by entering the first state in the SCXML.
:)
declare
  %rest:path("/blackjack/startGame")
  %rest:GET
  updating function page:scxq_initialState()
{
  (
    page:updating_redirect('/blackjack/showGameState'),
    scxq:goToInitialState()
  )
};

(:
  Call showing the current game state.
:)
declare
  %rest:path("/blackjack/showGameState")
  %rest:GET
  function page:bj_showGameState()
{
  bj:showGameState()
};

(:
  Call for adding a new player with a given start amount of money.
:)
declare
  %rest:path("/blackjack/addPlayer/{$amountOfMoney}")
  %rest:GET
  updating function page:bj_addPlayer($amountOfMoney)
{
  (
    page:updating_redirect('/blackjack/showGameState'),
    bj:addPlayer($amountOfMoney),
    scxq:receiveEvent('addPlayer')
  )
};

(:
  Call for removing the player with the given ID.
:)
declare
  %rest:path("/blackjack/removePlayer/{$playerId}")
  %rest:GET
  updating function page:bj_removePlayer($playerId)
{
  (
    page:updating_redirect('/blackjack/showGameState'),
    bj:removePlayer($playerId),
    scxq:receiveEvent('removePlayer')
  )
};

(:
  Call for starting a new turn of the game.
:)
declare
  %rest:path("/blackjack/newTurn")
  %rest:GET
  updating function page:bj_newTurn()
{
  (
    page:updating_redirect('/blackjack/showGameState'),
    bj:newTurn()
  )
};

(:
  Call for bidding a given amount of money for the current turn.
:)
declare
  %rest:path("/blackjack/bid/{$amountOfMoney}")
  %rest:GET
  updating function page:bj_bid($amountOfMoney)
{
  (
    page:updating_redirect('/blackjack/showGameState'),
    bj:bid($amountOfMoney),
    scxq:receiveEvent('bidWasSet')
  )
};

(:
  Call for hit (drawing another card).
:)
declare
  %rest:path("/blackjack/hit")
  %rest:GET
  updating function page:bj_hit()
{
  (
    page:updating_redirect('/blackjack/showGameState'),
    bj:hit()
  )
};

(:
  Call for stand (done with drawing any additional cards).
:)
declare
  %rest:path("/blackjack/stand")
  %rest:GET
  updating function page:bj_stand()
{
  (
    page:updating_redirect('/blackjack/showGameState'),
    bj:stand()
  )
};

(: ----- Redirect Helper ------ :)

(:
  Executes the URL redirect for an updating function.
:)
declare updating function page:updating_redirect($redirect as xs:string)
{
  db:output(page:redirect($redirect))
};

(:
  Returns the XML response, which leads to a redirect to the given URL.
:)
declare 
  function page:redirect($redirect as xs:string)
  as element(restxq:redirect)
{
    <restxq:redirect>{$redirect}</restxq:redirect>
};