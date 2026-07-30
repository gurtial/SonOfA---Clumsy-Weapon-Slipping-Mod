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
; MUST match the literal used in the "new" calls in _EnsureArrays().
int   Property MaxTracked   = 10   AutoReadOnly
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

; Ring buffer of watched world references + the realtime each was dropped.
ObjectReference[] tracked
float[]           dropAt
int   nextSlot        = 0
bool  polling         = false
float lastRollTime    = 0.0
float lastTripTime    = 0.0
float lastNpcTripTime = 0.0

; ---------------------------------------------------------------------------
Event OnInit()
	_ResolveForms()
	_EnsureArrays()
EndEvent

; Called by the player alias on first init and after every game load. Update
; timers do not survive a reload, so the poll loop is always dropped here and
; restarts on the next drop. (Inventory events on the alias re-arm themselves.)
Function OnLoad()
	_ResolveForms()
	_EnsureArrays()
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
	_EnsureArrays()
	tracked[nextSlot] = akRef
	dropAt[nextSlot]  = Utility.GetCurrentRealTime()
	nextSlot += 1
	if nextSlot >= MaxTracked
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
	_EnsureArrays()
	float now    = Utility.GetCurrentRealTime()
	float window = _F(SoaWindow, 60.0)
	float radius = _F(SoaRadius, 75.0)

	bool canRoll    = (now - lastRollTime) >= RollGap
	bool rolled     = false
	bool anyTracked = false

	int i = 0
	while i < MaxTracked
		ObjectReference r = tracked[i]
		if r != None
			if (now - dropAt[i]) > window
				tracked[i] = None                 ; timed out
			elseif r.IsDeleted()
				tracked[i] = None                 ; picked up / cleaned up
			else
				anyTracked = true
				if !rolled && canRoll && r.Is3DLoaded() && !r.IsDisabled()
					int res = _TryRollOn(r, radius, now)   ; 0 none, 1 miss, 2 trip
					if res >= 1
						rolled = true                 ; one roll per tick
						lastRollTime = now
						if res == 2
							tracked[i] = None         ; don't instantly re-trip on it
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

; The actual "trip": push the actor away from the thing under their feet. A push
; magnitude of 0 just knocks them down where they stand; higher values launch them.
Function _DoTrip(Actor a, ObjectReference from, bool isPlayer)
	from.PushActorAway(a, _F(SoaShove, 0.0))
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
	_EnsureArrays()
	int i = 0
	while i < MaxTracked
		tracked[i] = None
		i += 1
	endwhile
EndFunction

Function _EnsureArrays()
	if tracked == None
		tracked = new ObjectReference[10]   ; length MUST equal MaxTracked
		dropAt  = new float[10]
	endif
EndFunction

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
