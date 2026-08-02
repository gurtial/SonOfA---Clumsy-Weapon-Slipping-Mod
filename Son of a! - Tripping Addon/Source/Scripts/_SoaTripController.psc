Scriptname _SoaTripController extends Quest
{ Son of a! - Tripping (addon for the Clumsy Weapon Slipping Mod)

  Watches items the player drops into the world and, while any of them are
  nearby, rolls a chance to make whoever walks over one *trip* -- i.e. ragdoll.
  The player is always eligible; NPCs are optional (off by default).

  It hooks nothing but the player's own inventory, so it needs no other mod --
  but it pairs perfectly with "Son of a! - Clumsy Weapon Slipping": a weapon that
  slips out of your hand is just an item you dropped, so the very sword you fumbled
  becomes the thing you faceplant over a second later. That is the whole joke. }

; ---------------------------------------------------------------------------
; This plugin's own file name. Used to resolve our GlobalVariables at runtime
; so the ESP needs no script properties (keeps the plugin trivially small).
; ---------------------------------------------------------------------------
String Property PluginFile = "SonOfATripping.esp" AutoReadOnly

; How many recently-dropped world references we actively watch at once.
; IMPORTANT: this is a plain count, NOT an array length. We deliberately do NOT
; use Papyrus arrays: on some setups the runtime "new Type[n]" (ArrayCreate) op
; fails outright ("Cannot create an array into a non-array variable"), which
; silently killed the whole mod. So the ring buffer below is a handful of
; discrete member variables reached through _GetRef/_SetRef -- no arrays at all.
int   Property Slots        = 5    AutoReadOnly
; How often (seconds) we re-check the player's footing while objects are watched.
float Property PollInterval = 0.35 AutoReadOnly
; Minimum gap (seconds) between trip *rolls*, so standing on a pile isn't a dice
; storm and a single walk-over is one fair roll rather than several.
float Property RollGap      = 0.75 AutoReadOnly

; Cached forms / settings (all persist in the save game once resolved)
Actor PlayerRef

GlobalVariable SoaEnabled      ; master on/off                     (0x800)
GlobalVariable SoaTripChance   ; % chance the player trips         (0x801)
GlobalVariable SoaWeaponsOnly  ; only dropped weapons are trippable(0x802)
GlobalVariable SoaWindow       ; seconds a drop stays "trippable"  (0x803)
GlobalVariable SoaRadius       ; units that count as "on it"       (0x804)
GlobalVariable SoaShove        ; ragdoll force (0 = gentle flop)   (0x805)
GlobalVariable SoaNpcEnabled   ; let NPCs trip too                 (0x806)
GlobalVariable SoaNpcChance    ; % chance an NPC trips             (0x807)
GlobalVariable SoaNotify       ; toast when the player trips       (0x808)
GlobalVariable SoaCooldown     ; seconds between successful trips  (0x809)

; Discrete ring buffer of watched world refs + the realtime each was dropped.
; (No arrays -- see the note on Slots above.) Slots MUST equal the number of
; w#/s# pairs here and the fan-out in _GetRef/_SetRef/_GetStamp/_SetStamp.
ObjectReference w0
ObjectReference w1
ObjectReference w2
ObjectReference w3
ObjectReference w4
float s0
float s1
float s2
float s3
float s4
int   nextSlot        = 0
bool  polling         = false
float lastRollTime    = 0.0
float lastTripTime    = 0.0
float lastNpcTripTime = 0.0

; ---------------------------------------------------------------------------
Event OnInit()
	_ResolveForms()
EndEvent

; Called by the player alias on first init and after every game load. Update
; timers do not survive a reload, so the poll loop is always dropped here and
; restarts on the next drop. (Inventory events on the alias re-arm themselves.)
Function OnLoad()
	_ResolveForms()
	; A fresh game session (quit + relaunch) resets Utility.GetCurrentRealTime()
	; back to ~0, but our stored timestamps persist in the save -- so every
	; "now - stored" would read negative and jam the window / roll / cooldown
	; logic (poll forever, or never trip). A watched drop is only a few seconds
	; of fun anyway, so just start every load with a clean slate.
	_ClearTracked()
	nextSlot        = 0
	lastRollTime    = 0.0
	lastTripTime    = 0.0
	lastNpcTripTime = 0.0
	polling         = false
EndFunction

; ---------------------------------------------------------------------------
; Called by the player alias whenever the player drops something into the world.
Function NotifyDropped(Form akBaseItem, ObjectReference akRef)
	if akRef == None || !_IsOn()
		return
	endif
	; "Weapons only" filter (default on). Off = anything you drop can trip you.
	if SoaWeaponsOnly != None && SoaWeaponsOnly.GetValue() >= 0.5
		if (akBaseItem as Weapon) == None
			return
		endif
	endif
	_SetRef(nextSlot, akRef)
	_SetStamp(nextSlot, Utility.GetCurrentRealTime())
	nextSlot += 1
	if nextSlot >= Slots
		nextSlot = 0
	endif
	_StartPolling()
EndFunction

; ---------------------------------------------------------------------------
Event OnUpdate()
	polling = false
	if !_IsOn()
		_ClearTracked()              ; disabled -> forget pending drops so a later
		return                       ; re-enable starts clean, and let the loop die
	endif
	if _Tick()
		polling = true
		RegisterForSingleUpdate(PollInterval)
	endif
EndEvent

; One poll pass. Prunes dead/expired refs, rolls at most one trip, and reports
; whether anything is still worth watching (so we know to keep polling).
bool Function _Tick()
	float now    = Utility.GetCurrentRealTime()
	float window = _F(SoaWindow, 60.0)
	float radius = _F(SoaRadius, 75.0)

	bool canRoll    = (now - lastRollTime) >= RollGap
	bool rolled     = false
	bool anyTracked = false

	int i = 0
	while i < Slots
		ObjectReference r = _GetRef(i)
		if r != None
			if (now - _GetStamp(i)) > window
				_SetRef(i, None)                  ; timed out
			elseif r.IsDeleted()
				_SetRef(i, None)                  ; picked up / cleaned up
			else
				anyTracked = true
				if !rolled && canRoll && r.Is3DLoaded() && !r.IsDisabled()
					int res = _TryRollOn(r, radius, now)   ; 0 none, 1 miss, 2 trip
					if res >= 1
						rolled = true                 ; one roll per tick
						lastRollTime = now
						if res == 2
							_SetRef(i, None)          ; don't instantly re-trip on it
						endif
					endif
				endif
			endif
		endif
		i += 1
	endwhile

	return anyTracked
EndFunction

; Try to trip whoever is standing on ref r. Player takes priority over NPCs.
; Returns 0 = nobody on it, 1 = someone was on it but the roll missed, 2 = tripped.
int Function _TryRollOn(ObjectReference r, float radius, float now)
	; ---- player ----
	if (now - lastTripTime) >= _F(SoaCooldown, 3.0)
		if PlayerRef.GetDistance(r) <= radius && !_PlayerBusy()
			if Utility.RandomFloat(0.0, 100.0) <= _F(SoaTripChance, 25.0)
				_DoTrip(PlayerRef, r, true)
				lastTripTime = now
				return 2
			endif
			return 1
		endif
	endif
	; ---- npc (optional) ----
	; NPCs get their own cooldown so a pile of dropped items can't ragdoll-chain
	; one bystander, and so NPC trips never eat into (or borrow from) yours.
	if SoaNpcEnabled != None && SoaNpcEnabled.GetValue() >= 0.5 && (now - lastNpcTripTime) >= _F(SoaCooldown, 3.0)
		Actor a = Game.FindClosestActorFromRef(r, radius)
		if a != None && a != PlayerRef && _NpcTrippable(a)
			if Utility.RandomFloat(0.0, 100.0) <= _F(SoaNpcChance, 15.0)
				_DoTrip(a, r, false)
				lastNpcTripTime = now
				return 2
			endif
			return 1
		endif
	endif
	return 0
EndFunction

; The actual "trip": push the actor away from the thing under their feet. The
; force floors at a small value so a "0" setting still produces a real knockdown
; rather than a no-op -- a trip that doesn't put you on the floor isn't a trip.
Function _DoTrip(Actor a, ObjectReference from, bool isPlayer)
	float force = _F(SoaShove, 0.0)
	if force < 2.0
		force = 2.0
	endif
	from.PushActorAway(a, force)
	if isPlayer && SoaNotify != None && SoaNotify.GetValue() >= 0.5
		Debug.Notification("Son of a! You tripped!")
	endif
EndFunction

; ---------------------------------------------------------------------------
; Guards: don't yank someone out of an animation that would look broken.
bool Function _PlayerBusy()
	if PlayerRef.GetSitState() != 0 || PlayerRef.IsOnMount() || PlayerRef.IsSwimming()
		return true
	endif
	return PlayerRef.IsInKillMove() || PlayerRef.GetAnimationVariableBool("bInJumpState")
EndFunction

bool Function _NpcTrippable(Actor a)
	; Is3DLoaded first: PushActorAway on a not-fully-loaded actor can CTD.
	if !a.Is3DLoaded() || a.IsDead() || a.IsDisabled() || a.IsBleedingOut()
		return false
	endif
	if a.GetSitState() != 0 || a.IsOnMount() || a.IsSwimming() || a.IsInKillMove()
		return false
	endif
	return !a.GetAnimationVariableBool("bInJumpState")
EndFunction

; ---------------------------------------------------------------------------
Function _StartPolling()
	if !polling
		polling = true
		RegisterForSingleUpdate(PollInterval)
	endif
EndFunction

Function _ClearTracked()
	int i = 0
	while i < Slots
		_SetRef(i, None)
		i += 1
	endwhile
EndFunction

; ---- discrete-slot accessors (stand in for a Papyrus array) -----------------
ObjectReference Function _GetRef(int i)
	if i == 0
		return w0
	elseif i == 1
		return w1
	elseif i == 2
		return w2
	elseif i == 3
		return w3
	elseif i == 4
		return w4
	endif
	return None
EndFunction

Function _SetRef(int i, ObjectReference r)
	if i == 0
		w0 = r
	elseif i == 1
		w1 = r
	elseif i == 2
		w2 = r
	elseif i == 3
		w3 = r
	elseif i == 4
		w4 = r
	endif
EndFunction

float Function _GetStamp(int i)
	if i == 0
		return s0
	elseif i == 1
		return s1
	elseif i == 2
		return s2
	elseif i == 3
		return s3
	elseif i == 4
		return s4
	endif
	return 0.0
EndFunction

Function _SetStamp(int i, float t)
	if i == 0
		s0 = t
	elseif i == 1
		s1 = t
	elseif i == 2
		s2 = t
	elseif i == 3
		s3 = t
	elseif i == 4
		s4 = t
	endif
EndFunction

; ---------------------------------------------------------------------------
bool Function _IsOn()
	return SoaEnabled != None && SoaEnabled.GetValue() >= 0.5
EndFunction

; GlobalVariable value with a fallback if the form somehow didn't resolve.
float Function _F(GlobalVariable g, float fallback)
	if g == None
		return fallback
	endif
	return g.GetValue()
EndFunction

Function _ResolveForms()
	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif
	if SoaEnabled == None
		SoaEnabled     = _G(0x800)
		SoaTripChance  = _G(0x801)
		SoaWeaponsOnly = _G(0x802)
		SoaWindow      = _G(0x803)
		SoaRadius      = _G(0x804)
		SoaShove       = _G(0x805)
		SoaNpcEnabled  = _G(0x806)
		SoaNpcChance   = _G(0x807)
		SoaNotify      = _G(0x808)
		SoaCooldown    = _G(0x809)
	endif
EndFunction

GlobalVariable Function _G(int localId)
	return Game.GetFormFromFile(localId, PluginFile) as GlobalVariable
EndFunction
