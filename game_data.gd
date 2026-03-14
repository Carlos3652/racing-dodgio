extends Node

# Shared state passed between scenes
var finish_order: Array[Dictionary] = []  # [{name: String, time: float}]

# Car selection — set by main_menu, read by race_manager
var player_color: Color = Color(1.0, 0.133, 0.133, 1)  # default red
var player_car_type: String = "player"  # visual style key

# Car stats — set by main_menu from CAR_OPTIONS, read by player_car
var player_max_speed: float = 350.0
var player_stun_duration: float = 2.0
var player_boost_duration: float = 5.0

# Difficulty — set by main_menu, read by ai_car and race_manager
var difficulty: String = "normal"

# Replay + Share data — written by race_manager at race end
var track_points: Array = []              # Array[Vector2] — track waypoints
var final_positions: Dictionary = {}      # {car_name: Vector2} — where each car ended
var race_stats: Dictionary = {}           # {stars: int, stuns: int, bumps: int, boost_pct: float, lead_changes: int}

# ---------------------------------------------------------------------------
# 5-Race Circuit Mode
# ---------------------------------------------------------------------------
const TOTAL_LAPS = 3
const F1_POINTS = [10, 6, 4, 2, 1]

const TRACKS = [
	# -------------------------------------------------------------------------
	# Track 0 — Overland Park Loop
	# A clean clockwise oval with gently swept corners. Generous spacing between
	# waypoints keeps Curve2D arcs smooth at every corner. Good starter track —
	# the shape is immediately readable from the minimap and there are no trick
	# sections. Two long straights on the east and west flanks reward boost use.
	# Start (top-right) and finish (bottom-right) are ~700 px apart.
	# -------------------------------------------------------------------------
	{
		name = "Overland Park Loop",
		# Stars: one on each straight, two near the wide sweeping corners
		star_offsets = [0.12, 0.37, 0.62, 0.85],
		# Jeeps: mid-straight where you're going fastest and can't dodge early
		jeep_offsets = [0.25, 0.52, 0.78],
		points = [
			Vector2( 1000,  -300),
			Vector2( 1000, -1000),
			Vector2(  400, -1600),
			Vector2( -400, -1600),
			Vector2(-1000, -1000),
			Vector2(-1000,     0),
			Vector2(-1000,  1000),
			Vector2( -400,  1600),
			Vector2(  400,  1600),
			Vector2( 1000,  1000),
			Vector2( 1000,   400),
			Vector2( 1000,  -300),
		]
	},
	# -------------------------------------------------------------------------
	# Track 1 — Downtown Sprint
	# A stadium-style course built from four distinct chicane sections. No
	# right-angle corners — every bend is approached at 30-60 degrees so the
	# Curve2D interpolation produces a driveable arc. The north hairpin
	# (the tight u-turn at the top) is the signature moment — you have to brake
	# early or you'll ride the wall. The south return straight is the longest
	# flat section in the game. Clockwise.
	# -------------------------------------------------------------------------
	{
		name = "Downtown Sprint",
		# Stars: approach to the north hairpin, mid south straight, chicane apex
		star_offsets = [0.14, 0.40, 0.60, 0.82],
		# Jeeps: entry to the hairpin (punishes late braking), mid south straight
		jeep_offsets = [0.28, 0.55, 0.76],
		points = [
			Vector2(  800,  400),
			Vector2( 1400,    0),
			Vector2( 1600, -500),
			Vector2( 1400,-1000),
			Vector2(  800,-1400),
			Vector2(    0,-1400),
			Vector2( -600,-1000),
			Vector2( -800, -400),
			Vector2( -600,  200),
			Vector2(    0,  600),
			Vector2(  400,  600),
			Vector2(  800,  400),
		]
	},
	# -------------------------------------------------------------------------
	# Track 2 — Lakeside Curves
	# A flowing figure-of-three shape — three rounded lobes connected by short
	# linking straights. Every section curves into the next with no hard pivots.
	# The western lobe (bottom-left) is the widest and fastest. The eastern lobe
	# (top-right) is the tightest and where most position changes happen. The
	# rhythm of slow-fast-slow makes the boost timing interesting. Clockwise.
	# -------------------------------------------------------------------------
	{
		name = "Lakeside Curves",
		# Stars: each lobe apex — rewards staying on the racing line
		star_offsets = [0.17, 0.42, 0.67, 0.88],
		# Jeeps: the linking straights between lobes — unavoidable choke points
		jeep_offsets = [0.30, 0.56, 0.80],
		points = [
			Vector2(  600,  200),
			Vector2( 1200, -200),
			Vector2( 1400, -800),
			Vector2( 1000,-1300),
			Vector2(  200,-1400),
			Vector2( -400,-1000),
			Vector2( -200, -400),
			Vector2(  200,  -50),
			Vector2( -200,  400),
			Vector2( -600,  900),
			Vector2( -200, 1300),
			Vector2(  500, 1200),
			Vector2(  800,  700),
			Vector2(  600,  200),
		]
	},
	# -------------------------------------------------------------------------
	# Track 3 — Figure Eight
	# A true figure-eight with the crossover deliberately offset so the two
	# loops are at clearly different Y positions on screen (-1000 for the north
	# loop, +1000 for the south loop). The crossover zone runs through Y=0 on a
	# diagonal so cars crossing it are travelling perpendicular to each other —
	# visually obvious and spatially clear. The north loop is tighter; the south
	# loop is wider and faster. Direction: north loop clockwise, south loop
	# counter-clockwise (the natural figure-eight pattern).
	# Start at Vector2(400, 200); finish at Vector2(400, 700) — 500px apart.
	# Combined with the track_progress >= 500 guard, instant-finish is impossible.
	# -------------------------------------------------------------------------
	{
		name = "Figure Eight",
		# Stars: one per loop apex, one at each crossover approach
		star_offsets = [0.13, 0.38, 0.63, 0.88],
		# Jeeps: crossover zone entry (tight, must dodge) + one per loop straight
		jeep_offsets = [0.22, 0.50, 0.75],
		points = [
			Vector2(  400,  200),
			Vector2(  900, -200),
			Vector2(  900, -700),
			Vector2(  400,-1100),
			Vector2( -200,-1100),
			Vector2( -700, -700),
			Vector2( -700, -200),
			Vector2( -200,  150),
			Vector2( -700,  500),
			Vector2( -700, 1000),
			Vector2( -200, 1400),
			Vector2(  400, 1400),
			Vector2(  900, 1000),
			Vector2(  900,  500),
			Vector2(  400,  700),
			Vector2(  400,  200),
		]
	},
	# -------------------------------------------------------------------------
	# Track 4 — Championship Finale
	# The longest and most complex circuit. Four distinct sectors: a fast
	# sweeping opener, a technical hairpin complex in the north, a high-speed
	# blast through the west, and a punishing multi-apex final sector in the
	# south before the finish. Bounding box ~3400 x 2800 px — noticeably larger
	# than any other track. Five stars and four jeeps reflect the extended
	# length. The final chicane (last 3 waypoints) is deliberately tight to
	# create last-second position swings. Clockwise.
	# -------------------------------------------------------------------------
	{
		name = "Championship Finale",
		star_offsets = [0.10, 0.26, 0.45, 0.64, 0.82],
		jeep_offsets = [0.18, 0.38, 0.58, 0.78],
		points = [
			Vector2( 1200,  400),
			Vector2( 1600,    0),
			Vector2( 1800, -600),
			Vector2( 1600,-1200),
			Vector2( 1000,-1700),
			Vector2(  200,-1900),
			Vector2( -600,-1700),
			Vector2(-1100,-1200),
			Vector2(-1300, -600),
			Vector2(-1100,  100),
			Vector2( -600,  600),
			Vector2(    0,  900),
			Vector2(  200,  400),
			Vector2(  600,  100),
			Vector2(  900,  700),
			Vector2( 1200,  400),
		]
	},
]

# Circuit state
var circuit_mode: bool = false
var circuit_race: int = 0          # 0-based: which race we're on (0..4)
var circuit_standings: Dictionary = {}  # {car_name: int (total points)}
var circuit_history: Array = []    # [{track_name, finish_order}] per completed race
var current_track_index: int = 0
var circuit_total_stats: Dictionary = {}  # accumulated race_stats across all circuit races


func clear():
	# Per-race reset — preserves circuit state
	finish_order.clear()
	track_points.clear()
	final_positions.clear()
	race_stats.clear()


func clear_circuit():
	# Full reset — wipes everything including circuit
	clear()
	circuit_mode = false
	circuit_race = 0
	circuit_standings.clear()
	circuit_history.clear()
	circuit_total_stats.clear()
	current_track_index = 0


func record_circuit_race():
	# Accumulate F1 points from current finish_order into circuit_standings
	for i in range(finish_order.size()):
		var car_name = finish_order[i].name
		var pts = F1_POINTS[i] if i < F1_POINTS.size() else 0
		if circuit_standings.has(car_name):
			circuit_standings[car_name] += pts
		else:
			circuit_standings[car_name] = pts

	# Record history for this race
	var track_name = TRACKS[current_track_index].name if current_track_index < TRACKS.size() else "Unknown"
	var race_record = {
		track_name = track_name,
		finish_order = finish_order.duplicate(true),
	}
	circuit_history.append(race_record)

	# Accumulate race stats into circuit totals
	for key in race_stats.keys():
		if circuit_total_stats.has(key):
			circuit_total_stats[key] += race_stats[key]
		else:
			circuit_total_stats[key] = race_stats[key]

	# Advance to next race
	circuit_race += 1
