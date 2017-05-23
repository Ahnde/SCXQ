# SCXQ

A prototypical implementation of an SCXML-Interpreter in XQuery.

## Installation
The SCXML-Interpreter can be integrated into any existing BaseX Project. 
To do so add the 'scxml-interpreter.xqm' file to the webapp folder of the BaseX project. 

The interpreters dependency is functx. Either also add the functx.xqm file to the webapp folder or integrate it as module. In the latter case, adapt the import statement in 'scxml-interpreter.xqm'.

Since the SCXML can send events to your custom envirnoment, the last step is to import the handler module for the external events.
Implement the handler and reference it in 'scxml-interpreter.xqm'.

For more details check how the references are set in the example project.

## Usage
The SCXML has to be in the static folder of the webapp.

To run the application simply run .basex/bin/basexhttp. 

## Examples
[https://github.com/Ahnde/SCXQ/tree/master/example][examples]

[examples]: https://github.com/Ahnde/SCXQ/tree/master/example


## Copyright
See [LICENSE][] for details.

[license]: LICENSE.md
