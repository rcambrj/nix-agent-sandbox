{ lib }:
name: value:
lib.optionalString (value != null && toString value != "") "--${name}=${lib.escapeShellArg (toString value)}"
