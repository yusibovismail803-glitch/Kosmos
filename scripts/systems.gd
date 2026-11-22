class_name Systems
extends RefCounted

const PLANET_COLORS := [
	"#8fb8ff", "#ffb27a", "#c9d6e8", "#ff8a7a", "#9fe0c0",
	"#e0c68a", "#b8a0ff", "#7fd8ff", "#d0e8b0", "#f0a0c0",
]

const LIST := [
	{
		"id": "sys_alpha_centauri", "name": "Альфа Центавра + Проксима",
		"kind": "binary", "m1": 6.0, "m2": 5.5, "sep": 420.0,
		"count": 3, "seed": 101, "moons": 1,
		"inner": 1800.0, "step": 400.0,
		"third_m": 1.2, "third_rad": 22.0, "third_c": "#ff7a5a",
		"third_sep": 4000.0, "third_planets": 1,
	},
	{
		"id": "sys_sirius", "name": "Сириус",
		"kind": "binary", "m1": 8.0, "m2": 2.0, "sep": 380.0,
		"rad2": 16.0, "c2": "#d8ecff", "count": 2, "seed": 103,
	},
	{
		"id": "sys_barnard", "name": "Звезда Барнарда",
		"kind": "single", "m1": 1.0, "rad1": 20.0, "c1": "#ff6a5a",
		"count": 2, "inner": 240.0, "seed": 104,
	},
	{
		"id": "sys_trappist", "name": "TRAPPIST-1",
		"kind": "single", "m1": 0.9, "rad1": 19.0, "c1": "#ff8a6a",
		"count": 7, "inner": 110.0, "step": 22.0, "seed": 105, "scripted": 1,
	},
	{
		"id": "sys_kepler186", "name": "Kepler-186",
		"kind": "single", "m1": 1.1, "rad1": 21.0, "c1": "#ff7a5a",
		"count": 4, "inner": 240.0, "step": 150.0, "seed": 106,
	},
	{
		"id": "sys_kepler452", "name": "Kepler-452",
		"kind": "single", "m1": 6.0,
		"count": 2, "seed": 107, "moons": 1,
	},
	{
		"id": "sys_gliese581", "name": "Gliese 581",
		"kind": "single", "m1": 1.3, "rad1": 23.0, "c1": "#ff7a5a",
		"count": 4, "inner": 250.0, "step": 160.0, "seed": 108,
	},
	{
		"id": "sys_tauceti", "name": "Тау Кита",
		"kind": "single", "m1": 5.8,
		"count": 4, "seed": 109, "moons": 1,
	},
	{
		"id": "sys_eps_eridani", "name": "Эпсилон Эридана",
		"kind": "single", "m1": 4.5, "c1": "#ffb066",
		"count": 3, "seed": 110,
	},
	{
		"id": "sys_vega", "name": "Вега",
		"kind": "single", "m1": 8.5, "rad1": 56.0, "c1": "#bcd8ff",
		"count": 2, "inner": 500.0, "seed": 111,
	},
	{
		"id": "sys_betelgeuse", "name": "Бетельгейзе",
		"kind": "single", "m1": 11.0, "rad1": 88.0, "c1": "#ff5a3a",
		"count": 2, "inner": 700.0, "step": 240.0, "seed": 112,
	},
	{
		"id": "sys_rigel", "name": "Ригель",
		"kind": "single", "m1": 12.0, "rad1": 70.0, "c1": "#a8ccff",
		"count": 2, "inner": 700.0, "step": 240.0, "seed": 113,
	},
	{
		"id": "sys_antares", "name": "Антарес",
		"kind": "single", "m1": 10.0, "rad1": 84.0, "c1": "#ff5a3a",
		"count": 2, "inner": 680.0, "step": 240.0, "seed": 114,
	},
	{
		"id": "sys_polaris", "name": "Полярная",
		"kind": "single", "m1": 7.0, "rad1": 64.0, "c1": "#ffe6a0",
		"count": 3, "inner": 520.0, "step": 220.0, "seed": 115,
	},
	{
		"id": "sys_arcturus", "name": "Арктур",
		"kind": "single", "m1": 6.5, "rad1": 56.0, "c1": "#ffb066",
		"count": 3, "inner": 480.0, "seed": 116,
	},
	{
		"id": "sys_capella", "name": "Капелла",
		"kind": "binary", "m1": 6.0, "m2": 5.0, "sep": 400.0,
		"count": 3, "seed": 117, "moons": 1,
	},
	{
		"id": "sys_alderaan", "name": "Альдебаран",
		"kind": "single", "m1": 6.0, "rad1": 60.0, "c1": "#ffb066",
		"count": 2, "inner": 520.0, "seed": 118,
	},
	{
		"id": "sys_fomalhaut", "name": "Фомальгаут",
		"kind": "single", "m1": 7.0, "rad1": 50.0, "c1": "#d8ecff",
		"count": 3, "inner": 460.0, "seed": 119,
	},
	{
		"id": "sys_altair", "name": "Альтаир",
		"kind": "single", "m1": 7.2, "rad1": 48.0, "c1": "#e0f0ff",
		"count": 2, "inner": 420.0, "seed": 120,
	},
	{
		"id": "sys_deneb", "name": "Денеб",
		"kind": "single", "m1": 12.0, "rad1": 74.0, "c1": "#a8ccff",
		"count": 2, "inner": 720.0, "step": 240.0, "seed": 121,
	},
	{
		"id": "sys_procyon", "name": "Процион",
		"kind": "binary", "m1": 6.0, "m2": 2.0, "sep": 360.0,
		"rad2": 16.0, "c2": "#d8ecff", "count": 2, "seed": 122,
	},
	{
		"id": "sys_achernar", "name": "Ахернар",
		"kind": "single", "m1": 9.0, "rad1": 54.0, "c1": "#9ec8ff",
		"count": 2, "inner": 500.0, "seed": 123,
	},
	{
		"id": "sys_canopus", "name": "Канопус",
		"kind": "single", "m1": 8.0, "rad1": 66.0, "c1": "#fff0c0",
		"count": 3, "inner": 560.0, "step": 220.0, "seed": 124,
	},
	{
		"id": "sys_mira", "name": "Мира",
		"kind": "binary", "m1": 6.0, "m2": 2.0, "sep": 420.0,
		"rad1": 60.0, "c1": "#ff6a4a", "rad2": 16.0, "c2": "#d8ecff",
		"count": 2, "seed": 125,
	},
	{
		"id": "sys_albireo", "name": "Альбирео",
		"kind": "binary", "m1": 6.0, "m2": 5.0, "sep": 380.0,
		"c2": "#9ec8ff", "count": 2, "seed": 126,
	},
	{
		"id": "sys_51peg", "name": "51 Пегаса",
		"kind": "single", "m1": 5.8,
		"count": 2, "seed": 127,
	},
	{
		"id": "sys_hd189733", "name": "HD 189733",
		"kind": "single", "m1": 4.0, "rad1": 32.0, "c1": "#ffb066",
		"count": 2, "inner": 260.0, "seed": 128,
	},
	{
		"id": "sys_wasp12", "name": "WASP-12",
		"kind": "single", "m1": 5.5,
		"count": 2, "inner": 260.0, "seed": 129,
	},
	{
		"id": "sys_kepler16", "name": "Kepler-16",
		"kind": "binary", "m1": 5.0, "m2": 4.0, "sep": 340.0,
		"count": 3, "seed": 130, "moons": 1,
	},
]
