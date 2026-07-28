Scriptname _SoaClumsyController extends Quest
{ Son of a! - Clumsy Weapon Slipping Mod
  Main controller. Attached to the mod's start-game-enabled quest.
  Every melee swing rolls a chance for the equipped weapon to "slip" out of hand
  and get flung forward. A swing that has no enemy in front of it (i.e. you swung
  into a wall or thin air) uses a separate "wall" chance instead. Slips can also
  degrade the weapon's temper -- fully compatible with Loot and Degradation SE,
  which reads/writes the very same SKSE item-health value. }

; ---------------------------------------------------------------------------
; This plugin's own file name. Used to resolve our GlobalVariables at runtime
; so the ESP needs no script properties (keeps the plugin trivially small).
; ---------------------------------------------------------------------------
String Property PluginFile = "SonOfAClumsyWeapon.esp" AutoReadOnly

; How far in front an enemy must be for a swing to count as "at an enemy"
; rather than "into a wall". Covers melee reach plus lunges (e.g. BFCO/MCO).
float Property TargetReach   = 300.0 AutoReadOnly
float Property TargetConeDeg =  75.0 AutoReadOnly

; Cached forms / settings (all persist in the save game once resolved)
Actor           PlayerRef

GlobalVariable  SoaEnabled          ; master on/off              (0x800)
GlobalVariable  SoaSlipChance       ; % chance per swing at foe  (0x801)
GlobalVariable  SoaWallEnabled      ; enable wall/whiff slips    (0x802)
GlobalVariable  SoaWallSlipChance   ; % chance on a wall/whiff   (0x803)
GlobalVariable  SoaDegradeEnabled   ; enable degradation         (0x804)
GlobalVariable  SoaDegradeChance    ; % chance a slip degrades   (0x805)
GlobalVariable  SoaDegradeStep      ; temper %-points removed    (0x806)
GlobalVariable  SoaThrowForce       ; havok impulse magnitude    (0x807)
GlobalVariable  SoaNotify           ; show the "Son of a!" toast (0x808)

float lastSlipTime = 0.0            ; debounce so one hit can't double-fire

; ---------------------------------------------------------------------------
Event OnInit()
	_ResolveForms()
	ReRegister()
EndEvent

; Re-resolve any form that somehow came back None, then (re)register events.
; Called on first init and after every game load (via the player alias).
Function ReRegister()
	_ResolveForms()
	if PlayerRef == None
		return
	endif
	; Melee swings, right and left hand. (Bows/staves/crossbows never send these,
	; so ranged weapons are naturally excluded.)
	RegisterForAnimationEvent(PlayerRef, "weaponSwing")
	RegisterForAnimationEvent(PlayerRef, "weaponLeftSwing")
EndFunction

Function _ResolveForms()
	if PlayerRef == None
		PlayerRef = Game.GetPlayer()
	endif
	if SoaEnabled == None
		SoaEnabled        = _G(0x800)
		SoaSlipChance     = _G(0x801)
		SoaWallEnabled    = _G(0x802)
		SoaWallSlipChance = _G(0x803)
		SoaDegradeEnabled = _G(0x804)
		SoaDegradeChance  = _G(0x805)
		SoaDegradeStep    = _G(0x806)
		SoaThrowForce     = _G(0x807)
		SoaNotify         = _G(0x808)
	endif
EndFunction

GlobalVariable Function _G(int localId)
	return Game.GetFormFromFile(localId, PluginFile) as GlobalVariable
EndFunction

; ---------------------------------------------------------------------------
Event OnAnimationEvent(ObjectReference akSource, string asEventName)
	if akSource != PlayerRef || SoaEnabled == None
		return
	endif
	if SoaEnabled.GetValue() < 0.5
		return
	endif

	bool leftHand = (asEventName == "weaponLeftSwing")

	Weapon wp = PlayerRef.GetEquippedWeapon(leftHand)
	if wp == None
		return
	endif

	; Decide which chance applies: swinging AT an enemy, or into a wall / thin air.
	float chancePct
	if _EnemyInFront()
		chancePct = SoaSlipChance.GetValue()
	elseif SoaWallEnabled != None && SoaWallEnabled.GetValue() >= 0.5
		chancePct = SoaWallSlipChance.GetValue()
	else
		return   ; whiffed, but the wall/whiff feature is turned off
	endif

	_TrySlip(leftHand, chancePct, wp)
EndEvent

; Is there a living actor within reach and roughly in front of the player?
; If not, the swing is going into a wall or empty air.
bool Function _EnemyInFront()
	Actor a = Game.FindClosestActorFromRef(PlayerRef, TargetReach)
	if a == None || a == PlayerRef || a.IsDead()
		return false
	endif
	float rel = PlayerRef.GetHeadingAngle(a)   ; 0 = dead ahead, +/-180 = behind
	return (rel > -TargetConeDeg && rel < TargetConeDeg)
EndFunction

; Roll the chance for the given hand and slip if it hits.
Function _TrySlip(bool leftHand, float chancePct, Weapon wp)
	if chancePct <= 0.0
		return
	endif
	; Debounce: ignore anything within a fifth of a second of the last real slip
	; (keeps one attack that fires several swing annotations from double-firing).
	float now = Utility.GetCurrentRealTime()
	if (now - lastSlipTime) < 0.20
		return
	endif
	if Utility.RandomFloat(0.0, 100.0) > chancePct
		return
	endif

	lastSlipTime = now
	_SlipWeapon(wp, leftHand)
EndFunction

; Do the actual degrade-then-throw.
Function _SlipWeapon(Weapon wp, bool leftHand)
	; 1) Optional degradation FIRST, while the weapon is still equipped
	;    (SKSE's WornObject temper functions operate on the worn item).
	if SoaDegradeEnabled != None && SoaDegradeEnabled.GetValue() >= 0.5
		if Utility.RandomFloat(0.0, 100.0) <= SoaDegradeChance.GetValue()
			_DegradeEquipped(leftHand)
		endif
	endif

	; 2) Drop the weapon (this unequips it) and fling it forward.
	ObjectReference dropped = PlayerRef.DropObject(wp, 1)
	if dropped != None
		float angZ = PlayerRef.GetAngleZ()
		float x = Math.sin(angZ)      ; forward vector from heading (degrees)
		float y = Math.cos(angZ)
		float z = 0.35                ; a little arc so it doesn't scrape the floor
		float mag = 25.0
		if SoaThrowForce != None
			mag = SoaThrowForce.GetValue()
		endif
		dropped.ApplyHavokImpulse(x, y, z, mag)
	endif

	if SoaNotify != None && SoaNotify.GetValue() >= 0.5
		Debug.Notification("Son of a! Your weapon slipped!")
	endif
EndFunction

; Tier the equipped weapon's temper back down toward its untempered state.
; handSlot for WornObject: 0 = left hand, 1 = right hand. slotMask = 0.
Function _DegradeEquipped(bool leftHand)
	int handSlot = 1
	if leftHand
		handSlot = 0
	endif
	float h = WornObject.GetItemHealthPercent(PlayerRef, handSlot, 0)
	if h > 1.0
		float step = 0.10
		if SoaDegradeStep != None
			step = SoaDegradeStep.GetValue() / 100.0   ; slider is in %-points
		endif
		float newH = h - step
		if newH < 1.0
			newH = 1.0                                  ; never below untempered
		endif
		WornObject.SetItemHealthPercent(PlayerRef, handSlot, 0, newH)
	endif
EndFunction
