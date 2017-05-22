
module namespace scxq='http://www.w3.org/2005/07/scxml-xquery';

import module namespace functx='http://www.functx.com' at 'functx.xqm';

(: TODO import app, for being able to handle external events :)
(: import module namespace app='http://www.domain.org/myApp' at 'myApp.xqm';:)

(: --- -------------- --- :)
(: --- public methods --- :)
(: --- -------------- --- :)

(:
  Create the databases, which are needed for the SCXML-interpreter.
:)
declare
  updating function scxq:setup()
{
  scxq:_createDatabases()
};

(:
  Stores the initial configuration for the given SCXML in the database.
:)
declare
  updating function scxq:initialize()
{
  let $scxml := scxq:_getScxml()
  let $initialVariables := scxq:_createVariablesForScxml($scxml)
  let $initialConfig := scxq:_createScxmlConfig()
  return 
    (
      scxq:_setVariables($initialVariables),
      scxq:_setConfig($initialConfig)
    )
};

(:
  Enters the initial state of the SCMXL.
:)
declare
  updating function scxq:goToInitialState()
{
  let $scxml := scxq:_getScxml()
  let $initialStateId := scxq:_getInitialStateId($scxml)
  return scxq:_goToStateWithId($initialStateId)
};

(: 
  Handles and processes an event from the enviroment to the SCXML.
:)
declare
  updating function scxq:receiveEvent($event as xs:string)
{
  let $transition := scxq:_getTransitionForEvent($event)
  return scxq:_evaluateTransition($transition)
};

(:
  Sends an event from the SCXML.
  If the Target is 'external' then the webapp receives it. (Handler method must be implemented)
  Else the event is sent to the SCXML.
:)
declare
  updating function scxq:sendEvent($event, $target)
{
  if ($target = 'external') then
  	(: TODO call handler for external Events in app :)
    (: app:eventFromScxml($event) :)
  else
    scxq:receiveEvent($event)
};

(:
  Returns the ID of the current state.
:)
declare
  function scxq:getCurrentStateId()
{
  let $currentConfig := scxq:_getConfig()
  let $currentStateId := $currentConfig/scxmlConfig/currentStateId/text()
  return $currentStateId
};

(: 
  Returns the currently active variables of the SCXML.
:)
declare
  function scxq:getCurrentVariables()
{
  let $currentStateId := scxq:getCurrentStateId()
  let $activeStateIdSequence := scxq:_getParentStateIdSequenceForStateWithId($currentStateId)
  let $variableList := scxq:_getVariables()

  for $stateId in $activeStateIdSequence
    let $stateVariables := $variableList//state[@id=$stateId]/variables/child::node()
    return $stateVariables
};

(: 
  Returns the currently possible events of the SCXML.
:)
declare
  function scxq:getPossibleEvents()
{
  let $currentStateId := scxq:getCurrentStateId()
  let $activeStateIdSequence := reverse(scxq:_getParentStateIdSequenceForStateWithId($currentStateId))
  let $scxml := scxq:_getScxml()
  let $possibleEvents :=
    for $stateId in $activeStateIdSequence
      let $transitions := $scxml//state[@id=$stateId]/*[self::transition]
      let $events :=
        for $transition in $transitions
          let $event := string($transition/@event)
          return $event
      return $events
  let $eventsXml :=
    for $event in distinct-values($possibleEvents)
      let $eventXml := <event>{$event}</event>
      return $eventXml
  return <events>{$eventsXml}</events>
};


(: --- --------------- --- :)
(: --- private methods --- :)
(: --- --------------- --- :)


(: 
  Creates all databases.
:)
declare
  updating function scxq:_createDatabases()
{
  let $scxml := doc("./static/blackjack-scxml.xml")
  let $scxmlConfig := doc("./static/scxml-config.xml")
  let $scxmlVariables := doc("./static/scxml-variables.xml")
  return
    (
      db:create('scxml', $scxml, '/scxml.xml'),
      db:create('scxmlConfig', $scxmlConfig, '/scxml-config.xml'),
      db:create('scxmlVariables', $scxmlVariables, '/scxml-variables.xml')
    )
};

(: 
  Returns the SCXML.
:)
declare
  function scxq:_getScxml()
{
  let $scxml := db:open('scxml')/xml/*[self::scxml]
  return $scxml
};

(: 
  Returns the configuration file of the SCXML.
:)
declare
  function scxq:_getConfig()
{
  let $config := db:open('scxmlConfig')
  return $config
};

(: 
  Returns the list of currently set variables.
:)
declare
  function scxq:_getVariables()
{
  let $variables := db:open('scxmlVariables')
  return $variables
};

(: 
  Stores the given SCXML in the database.
:)
declare
  updating function scxq:_setScxml($scxml)
{
  db:replace('scxml', '/scxml.xml', $scxml)
};

(: 
  Stores the given configuration file in the database.
:)
declare
  updating function scxq:_setConfig($config)
{
  db:replace('scxmlConfig', '/scxml-config.xml', $config)
};

(: 
  Stores the given list of variables in the database.
:)
declare
  updating function scxq:_setVariables($variables)
{
  db:replace('scxmlVariables', '/scxml-variables.xml', $variables)
};

(: --- States --- :)
(: /// Initial State /// :)

(: 
  Returns the initial state of the SCXML.
:)
declare
  function scxq:_getInitialState($scxml)
{
  let $initialStateId := scxq:_getInitialStateId($scxml)
  let $initialState := scxq:_getStateWithId($initialStateId)
  return $initialState
};

(: 
  Returns the ID of the initial state of the SCXML.
:)
declare
  function scxq:_getInitialStateId($scxml)
{
  let $initialStateId := string($scxml/@initialState)
  return($initialStateId)
};

(: /// Parent State /// :)

(: 
  Returns the list of IDs for all parent states of the state with a given state ID.
  The first element is the upper most parent. The last element is the first parent.
:)
declare
  function scxq:_getParentStateIdSequenceForStateWithId($stateId)
{
  functx:value-union(reverse(scxq:_getReversedParentStateIdsForStateWithId($stateId)), ($stateId))
};

(: 
  Returns the list of IDs for all parent states of the state with a given state ID.
  The first element is the first parent. The last element is the upper most parent.
:)
declare
  function scxq:_getReversedParentStateIdsForStateWithId($stateId)
{
  let $scxml := scxq:_getScxml()
  let $currentState := scxq:_getStateWithId($stateId)
  let $parentState := $scxml//state[@id=$stateId]/parent::state
  let $parentStateId := scxq:_getIdOfState($parentState)

  let $parentStatesSequence := ($parentStateId)
  let $resultSequence := 
    if (empty($parentStateId) or $parentStateId = '') then
      ()
    else
      let $moreSequence := scxq:_getReversedParentStateIdsForStateWithId($parentStateId)
      return functx:value-union($parentStatesSequence, $moreSequence)
  return $resultSequence
};

(: /// Current State /// :)

(: 
  Sets the ID for the currently active state in the SCXML configuration file to the given state ID. 
:)
declare
  updating function scxq:_setCurrentStateId($stateId)
{
  let $currentConfig := scxq:_getConfig()
  return replace value of node $currentConfig/scxmlConfig/currentStateId with $stateId
};

(: 
  Returns the current state of the SCXML.
:)
declare
  function scxq:_getCurrentState()
{
  let $currentStateId := scxq:getCurrentStateId()
  let $currentState := scxq:_getStateWithId($currentStateId)
  return $currentState
};

(: /// General States /// :)

(: 
  Returns the root level states of a given SCXML. 
:)
declare
  function scxq:_getTopLevelStates($scxml)
{
  let $topLevelStates := scxq:_getChildStatesForState($scxml)
  return $topLevelStates
};

(: 
  Returns the whole state for a given ID. 
:)
declare
  function scxq:_getStateWithId($id)
{
  let $scxml := scxq:_getScxml()
  let $state := $scxml//state[@id=$id]
  return $state
};

(: 
  Returns the ID for a given state. 
:)
declare
  function scxq:_getIdOfState($state)
{
  let $stateId := string($state/@id)
  return $stateId
};

(: 
  Returns the ID of the immediate parent state of the state with the given state ID. 
:)
declare
  function scxq:_getIdOfParentStateForStateWithId($stateId)
{
  let $state := scxq:_getStateWithId($stateId)
  let $stateId := string($state/../@id)
  return $stateId
};

(: 
  Returns the childstates of the state with the given state ID. 
:)
declare
  function scxq:_getChildStatesForStateWithId($stateId)
{
  let $state := scxq:_getStateWithId($stateId)
  return scxq:_getChildStatesForState($state)
};

(: 
  Returns the childstates of the given state. 
:)
declare
  function scxq:_getChildStatesForState($state)
{
  let $childStates := $state/*[self::state]
  return $childStates
};

(: --- Execution --- :)

(: 
  Triggers the execution of all states in a given state ID list.
:)
declare
 updating function scxq:_handleOnEntryForSequenceOfStateIds($stateIdSequence)
{
  for $oneStateId in $stateIdSequence
    return scxq:_handleOnEntryForStateWithId($oneStateId)
};

(: 
  Extracts the recently handleable statements in the onentry statement of the state with the given ID.
  - Assignments (assign and var)
  - Events (send)
:)
declare
 updating function scxq:_handleOnEntryForStateWithId($stateId)
{
  let $state := scxq:_getStateWithId($stateId)
  let $onentry := $state/onentry
  let $assignments := $onentry/*[self::assign or self::var]
  let $sends := $onentry/*[self::send]
  return 
    (
      scxq:_handleAssignmentsForStateWithId($assignments, $stateId),
      scxq:_handleSends($sends)
    )
};

(: 
  Executes a list of assignments. 
:)
declare
  updating function scxq:_handleAssignmentsForStateWithId($actionsSequence, $stateId)
{
  if (empty($actionsSequence)) then
    ()
  else
    let $variableList := scxq:_getVariables()
    let $actions := <actions>{$actionsSequence}</actions>
    let $vars := $actions/*[self::var]
    let $assigns := $actions/*[self::assign or self::var]
    for $variable in $assigns
      let $name := string($variable/@name)
      let $expression := string($variable/@expr)
      let $newContent := scxq:_evalExpression($expression, 'true')
      let $variableStateId := scxq:_getStateIdForVariableWithNameOfStateWithId($name, $stateId)
      return replace value of node $variableList//state[@id=$variableStateId]/variables/variable[@name=$name] with $newContent
};

(: 
  Triggers the execution for a list of send events. 
:)
declare
  updating function scxq:_handleSends($sends)
{
  for $send in $sends
    let $event := string($send/@event)
    let $target := string($send/@target)
    return scxq:sendEvent($event, $target)
};


(: --- Transitions --- :)

(: 
  Returns the first valid transition for an event in the current state.
:)
declare
  function scxq:_getTransitionForEvent($event)
{
  let $currentStateId := scxq:getCurrentStateId()
  return scxq:_getTransitionForEventInStateWithId($event, $currentStateId)
};

(: 
  Returns the first valid transition for an event in a given state.
  That means, the condition of an transition has to be true (if given).
  First the transitions in the active state are checked. Then the ones in its parent state and so on.
  If a single state has multiple valid Transitions, the first one is chosen.
:)
declare
  function scxq:_getTransitionForEventInStateWithId($event, $stateId)
{
  let $state := scxq:_getStateWithId($stateId)
  let $transitions := $state/transition[@event=$event]
  let $indices :=
    for $trans at $position in $transitions
      let $condition := string($trans/@cond)
      return
        if ($condition = '' or scxq:_evalCondition($condition) = 'true') then
          let $transition := $trans
          return $position
        else
          ()
  let $firstIndex := $indices[1]
  let $transition := $transitions[$firstIndex]
  let $result := 
    if (empty($transition)) then
      let $parentStateId := scxq:_getIdOfParentStateForStateWithId($stateId)
      let $parentTransition := 
        if ($parentStateId = '') then
          ()
        else
          scxq:_getTransitionForEventInStateWithId($event, $parentStateId)
      return $parentTransition
    else
      $transition
  return $result
};

(: 
  Executes all the statements in a transition.
  Also triggers a change of the current state, if the transition has a target state.
:)
declare
  updating function scxq:_evaluateTransition($transition)
{
  let $currentStateId := scxq:getCurrentStateId()
  let $assignments := $transition/*[self::assign]
  let $nextStateId := string($transition/@target)
  return
    if ($nextStateId = '') then
      (
        scxq:_handleAssignmentsForStateWithId($assignments, $currentStateId)
      )
    else
      (
        scxq:_handleAssignmentsForStateWithId($assignments, $currentStateId),
        scxq:_goToStateWithId($nextStateId)
      )
};

(: 
  Enters the state with a given ID.
:)
declare
  updating function scxq:_goToStateWithId($stateId)
{ 
  let $currentStateId := scxq:getCurrentStateId()
  let $parentStateIdsSequenceForOldState := scxq:_getParentStateIdSequenceForStateWithId($currentStateId)
  let $parentStateIdsSequence := scxq:_getParentStateIdSequenceForStateWithId($stateId)
  let $intercept := functx:value-intersect($parentStateIdsSequenceForOldState, $parentStateIdsSequence)
  let $except := functx:value-except($parentStateIdsSequence, $intercept)
  let $stateIdsSequence := functx:value-except($except, ($currentStateId))
  return 
    (
      scxq:_handleOnEntryForSequenceOfStateIds($stateIdsSequence),
      scxq:_setCurrentStateId($stateId)
    )
};

(: --- Variables --- :)

(: 
  Returns the variable with a given name in the current state.
:)
declare
  function scxq:_getVariableWithName($variableName)
{
  let $stateId := scxq:getCurrentStateId()
  let $variable := scxq:_getVariableWithNameInStateWithId($variableName, $stateId)
  return $variable
};

(: 
  Returns the variable with a given name in the given state.
  If the variable cannot be found in this state, it is looked up in the parent state and so on.
  If no variable at all can be found an empty sequence is returned.
:)
declare
  function scxq:_getVariableWithNameInStateWithId($variableName, $stateId)
{
  let $variableStateId := scxq:_getStateIdForVariableWithNameOfStateWithId($variableName, $stateId)
  let $variable := 
    if (empty($variableStateId)) then
      ()
    else
      let $variablesOfState := scxq:_getVariablesForStateWithId($variableStateId)
      let $variableOfState := $variablesOfState/variable[@name=$variableName]
      return $variableOfState
  return $variable
};

(: 
  Returns the variable with a given name in the given state.
  If no variable can be found, the parent state i
:)
declare
  updating function scxq:_setVariableWithName($variableName, $variable, $variableList)
{
  let $currentStateId := scxq:getCurrentStateId()
  return scxq:_setVariableWithNameInStateWithId($variableName, $currentStateId, $variable, $variableList)
};

(: 
  Looks up the variable in the variable list and replaces its content.
:)
declare
  updating function scxq:_setVariableWithNameInStateWithId($variableName, $stateId, $variable, $variableList)
{
  let $variableStateId := scxq:_getStateIdForVariableWithNameOfStateWithId($variableName, $stateId)
  return scxq:_replaceVariableWithNameInStateWithId($variableName, $variableStateId, $variable, $variableList)
};

(: 
  Replaces a variable.
:)
declare
  updating function scxq:_replaceVariableWithNameInStateWithId($variableName, $stateId, $variable, $variableList)
{
  replace node $variableList//state[@id=$stateId]/variables/variable[@name=$variableName] with $variable
};

(: 
  Returns the ID of the state, a given variable is in. 
  The search begins in the current state and continues in its parent states.
:)
declare
  function scxq:_getStateIdForVariableWithName($variableName)
{
  let $currentStateId := scxq:getCurrentStateId()
  let $stateId := scxq:_getStateIdForVariableWithNameOfStateWithId($variableName, $currentStateId)
  return $stateId
};

(: 
  Returns the ID of the state, a given variable is in. 
  The search begins in a given state. If the variable cannot be found in this state, the search continues in its parent states.
:)
declare
  function scxq:_getStateIdForVariableWithNameOfStateWithId($variableName, $stateId)
{
  let $variablesInState := scxq:_getVariablesForStateWithId($stateId)
  let $variable := $variablesInState/variable[@name=$variableName]
  let $result := 
    if (empty($variable)) then
      let $parentStateId := scxq:_getIdOfParentStateForStateWithId($stateId)
      let $parentVariable := 
        if ($parentStateId = '') then
          ()
        else
          scxq:_getStateIdForVariableWithNameOfStateWithId($variableName, $parentStateId)
      return $parentVariable
    else
      $stateId
  return $result
};

(: 
  Returns the list of variables for a given state.
:)
declare
  function scxq:_getVariablesForStateWithId($stateId)
{
  let $variables := scxq:_getVariables()
  let $variablesInState := $variables//state[@id=$stateId]/variables
  return $variablesInState
};

(:
  Creates all variables for the given SCXML
:)
declare
  function scxq:_createVariablesForScxml($scxml)
{
  let $topLevelStates := scxq:_getTopLevelStates($scxml)
  let $variableList :=
    for $state in $topLevelStates
      return scxq:_createVariablesForStateAndChildStates($state)
  let $variableList2 := scxq:_createVariablesForStateAndChildStates($topLevelStates)
  return <variableList>{$variableList}</variableList>
};

(:
  Create all variables for a given state and its child states (recursively).
:)
declare
  function scxq:_createVariablesForStateAndChildStates($state)
{
  let $stateVariables := scxq:_createVariablesForState($state)
  let $childStates := scxq:_getChildStatesForState($state)
  let $childStateCount := count($childStates)
  let $childResult := 
    for $childState in $childStates
      let $childStateVariables := scxq:_createVariablesForStateAndChildStates($childState)
      return $childStateVariables
  let $stateId := scxq:_getIdOfState($state)
  let $variables := 
    <state id="{$stateId}">
      {$stateVariables}
      <childStateCount>{$childStateCount}</childStateCount>
      <childStates>{$childResult}</childStates>
    </state>
  return $variables
};

(:
  Create all variables for a given state
:)
declare
  function scxq:_createVariablesForState($state)
{
  let $variableTags := 
    for $variableTag in $state/onentry//var 
      let $variableName := string($variableTag/@name)
      let $variable := scxq:_createVariable($variableName, ())
      return $variable
  let $variablesForState := <variables>{$variableTags}</variables>
  return $variablesForState
};

(:
  Create a new variable
:)
declare
  function scxq:_createVariable($name, $expression)
{
  let $emptyVariable := <variable name="{$name}"></variable>
  let $variable := 
    if (empty($expression)) then
      $emptyVariable
    else
      let $content := scxq:_evalExpression($expression, 'true')
      return scxq:_modifyVariable($emptyVariable, $content)
  return $variable
};

(:
  TODO
:)
declare
  updating function scxq:_replaceMultipleVariablesInStateWithId($stateId, $variables, $variableList)
{
  for $variable in $variables
    let $name := string($variable/@name)
    let $expression := string($variable/@expr)
    let $oldVariable := scxq:_getVariableWithNameInStateWithId($name, $stateId)
    let $newContent := scxq:_evalExpression($expression, 'true')
    let $newVariable := scxq:_modifyVariable($oldVariable, $newContent)
    return scxq:_setVariableWithNameInStateWithId($name, $stateId, $newVariable, $variableList)
};

(:
  Erases the content of a given variable
:)
declare
  function scxq:_emptyVariable($variable)
{
  let $newVariable := scxq:_modifyVariable($variable, '')
  return newVariable
};

(:
  Modifies the content of a variable
:)
declare
  function scxq:_modifyVariable($variable, $content)
{
  let $mymodifiedVariable := functx:replace-element-values($variable, $content)
  return $mymodifiedVariable
};

(: --- Expressions --- :)

(:
  Evaluates a SCXML expression. First it checks if "jexl" is set.
  - Yes: evaluate the condition and return the result
  - No: return the expression as is
:)
declare
  function scxq:_evalExpression($expression as xs:string, $jexl as xs:string)
{
  let $jexlBool := scxq:_boolean($jexl)
  let $result := 
    if ($jexlBool and not(empty($expression)) and not($expression = '')) then
      scxq:_evalCondition($expression)
    else
      $expression
  return $result
};

(:
  Evaluates a SCMXL condition
  This method checks what kind of condition is given:
  - String: return the string
  - Number: return the number
  - Comparison: returns bool
  - Arithmetic expression: returns result
:)
declare
  function scxq:_evalCondition($condition as xs:string)
{
  let $result := 
    if (scxq:_isStringInCondition($condition)) then
      scxq:_removeQuotes($condition)
    else if (functx:is-a-number($condition)) then
      $condition
    else if (scxq:_isActiveVariable($condition)) then 
      scxq:_getContentIfVariable($condition)
    else if (contains($condition, '!=')) then 
      not(scxq:_isEqual(scxq:_getContentIfVariable(tokenize($condition, '\s*!=\s*')[1]), 
                        scxq:_getContentIfVariable(tokenize($condition, '\s*!=\s*')[2])))
    else if (contains($condition, '=')) then 
      scxq:_isEqual(scxq:_getContentIfVariable(tokenize($condition, '\s*=\s*')[1]), 
                    scxq:_getContentIfVariable(tokenize($condition, '\s*=\s*')[2]))
    else if (contains($condition, '<')) then
      scxq:_isGreater(scxq:_getContentIfVariable(tokenize($condition, '\s*<\s*')[2]),
                      scxq:_getContentIfVariable(tokenize($condition, '\s*<\s*')[1]))
    else if (contains($condition, '>')) then
      scxq:_isGreater(scxq:_getContentIfVariable(tokenize($condition, '\s*>\s*')[1]),
                      scxq:_getContentIfVariable(tokenize($condition, '\s*>\s*')[2]))
    else if (contains($condition, '+')) then
      scxq:_additionInCondition($condition)
    else if (contains($condition, '-')) then
      scxq:_arithmeticOperation($condition, '-')
    else if (contains($condition, '*')) then
      scxq:_arithmeticOperation($condition, '*')
    else if (contains($condition, '/')) then
      scxq:_arithmeticOperation($condition, '/')
    else
      scxq:_boolean($condition)
  
  return $result
};

(:
  Checks if the input is a variable.
  If yes: return content of variable
  If no: return input as is
:)
declare
  function scxq:_getContentIfVariable($variable)
{
  let $value :=
    if (scxq:_isActiveVariable($variable)) then
      let $variable := scxq:_getVariableWithName($variable)
      return $variable/text()
    else
      $variable
  return $value
};

(:
  Calculates the result of an arithmetic operation on a given condition.
  This is a special case since it could either be an arithmetic operation or a string concatenation.
:)
declare
  function scxq:_additionInCondition($condition as xs:string)
{
  let $tokens := tokenize($condition, '\s*\+\s*')
  let $left := scxq:_getContentIfVariable($tokens[1])
  let $right := scxq:_getContentIfVariable($tokens[2])
  let $isConcatination := (scxq:_isStringInCondition($left) or scxq:_isStringInCondition($right))
  let $result := 
    if ($isConcatination) then
      concat(scxq:_removeQuotes($left), scxq:_removeQuotes($right))
    else
      scxq:_arithmeticOperation($condition, '+')
  return $result
};

(:
  Calculates the result of an arithmetic operation on a given condition.
  Possible operations are:
  - '+' addition
  - '-' substraction
  - '*' multiplication
  - '/' division
:)
declare
  function scxq:_arithmeticOperation($condition as xs:string, $operation as xs:string)
{
  let $escapedOperation := 
    if ($operation = '+' or $operation = '*') then
      concat('\', $operation)
    else 
      $operation
  let $tokens := tokenize($condition, concat("\s*", $escapedOperation, "\s*"))
  let $left := scxq:_getContentIfVariable($tokens[1])
  let $right := scxq:_getContentIfVariable($tokens[2])
  let $result := 
    if ($operation = '+') then
      xs:integer($left) + xs:integer($right)
    else if ($operation = '-') then
      xs:integer($left) - xs:integer($right)
    else if ($operation = '*') then
      xs:integer($left) * xs:integer($right)
    else if ($operation = '/' or $operation = ':') then
      xs:integer($left) div xs:integer($right)
    else
      xs:integer($left) + xs:integer($right)
  return $result
};
    
(: 
  Checks if the content of a condition is a string. 
:)
declare
  function scxq:_isStringInCondition($condition as xs:string)
{
  let $tokens := tokenize($condition, "\s*'\s*")
  let $result := scxq:_boolean(count($tokens) = 3 and starts-with($condition, "'") and ends-with($condition, "'"))
  return $result
};

(:
  Checks if the condition an active variable in the SCXML. 
:)
declare
  function scxq:_isActiveVariable($condition)
{
  let $variable := scxq:_getVariableWithName($condition)
  let $isEmpty := empty($variable)
  return not($isEmpty)
};

(: 
  Checks if two values equal by using custom boolean function.
  Also covers the case that the "values" could be variables.
:)
declare
  function scxq:_isEqual($valueOne, $valueTwo)
{
  scxq:_boolean(not(compare($valueOne, $valueTwo)))
};

(: 
  Checks if one value is greater than another by using custom boolean function. 
:)
declare
  function scxq:_isGreater($valueOne, $valueTwo)
{
  scxq:_boolean(compare(xs:string($valueOne), xs:string($valueTwo)))
};

(: 
  Checks if the given value is true or false. Includes special SCXML cases. 
:)
declare
  function scxq:_boolean($value)
{
  let $result :=
    if ((functx:sequence-type($value) = 'xs:string' and (lower-case($value) = 'true' or $value = '1')) or
        (functx:sequence-type($value) = 'xs:integer' and $value = 1)) then
      'true'
    else if ((functx:sequence-type($value) = 'xs:string' and (lower-case($value) = 'false' or $value = '0')) or
             (functx:sequence-type($value) = 'xs:integer' and $value = 0)) then
      'false'
    else
      boolean($value)
  return $result
};

(: 
  Removes single Quotes from string. 
:)
declare
  function scxq:_removeQuotes($string)
{
  replace(replace($string,"'$",""),"^'+","")
};

(: 
  Creates the initial SCXML config.
:)
declare 
  function scxq:_createScxmlConfig()
{
  <scxmlConfig>
    <currentStateId/>
  </scxmlConfig>
};
