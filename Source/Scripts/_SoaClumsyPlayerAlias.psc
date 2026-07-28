Scriptname _SoaClumsyPlayerAlias extends ReferenceAlias
{ Son of a! - Clumsy Weapon Slipping Mod
  Forced-reference alias on the player. Its only job is to (re)arm the
  controller's animation-event registrations, which do not survive a save
  reload, so they must be re-registered on every game load. }

Event OnInit()
	_Kick()
EndEvent

Event OnPlayerLoadGame()
	_Kick()
EndEvent

Function _Kick()
	_SoaClumsyController ctrl = GetOwningQuest() as _SoaClumsyController
	if ctrl != None
		ctrl.ReRegister()
	endif
EndFunction
