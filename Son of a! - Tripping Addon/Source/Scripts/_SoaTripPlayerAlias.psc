Scriptname _SoaTripPlayerAlias extends ReferenceAlias
{ Son of a! - Tripping (addon)
  Forced-reference alias on the player. Two jobs:
   1) Catch every item the player drops into the world and hand the new world
      reference to the controller so it can be watched.
   2) Re-arm the controller's poll timer after a game load. }

Event OnInit()
	_Ctrl().OnLoad()
EndEvent

Event OnPlayerLoadGame()
	_Ctrl().OnLoad()
EndEvent

; Fires for anything leaving the player's inventory. A real *drop* is the only
; case where a world reference is created AND no destination container is set;
; selling, storing and giving all have a destination container instead.
Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
	if akDestContainer == None && akItemReference != None
		_SoaTripController ctrl = _Ctrl()
		if ctrl != None
			ctrl.NotifyDropped(akBaseItem, akItemReference)
		endif
	endif
EndEvent

_SoaTripController Function _Ctrl()
	return GetOwningQuest() as _SoaTripController
EndFunction
