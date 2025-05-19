# (Fictional) Tablet for VFR GPS navigation
#######################################

var tablet_start = nil;
var tablet_main = nil;
var tablet_display = nil;
var tablet_map = nil;

var base = "/instrumentation/tablet/";

var time_base = "/sim/time/utc/";


var start_prop = base~"start";
var volt_prop = "/systems/electrical/outputs/gps";

setprop(start_prop, 0);

var instrument_dir = "Aircraft/icon-a5/Models/Instruments/tablet/";


var canvas_tablet_base = {
	init: func(canvas_group, file) {
		var font_mapper = func(family, weight) {
			return "LiberationFonts/LiberationSans-Regular.ttf";
		};

		
		canvas.parsesvg(canvas_group, file, {'font-mapper': font_mapper});

		var svg_keys = me.getKeys();
		 
		foreach(var key; svg_keys) {
			me[key] = canvas_group.getElementById(key);
			print("canvas key "~key);
		}

		me.page = canvas_group;

		return me;
	},
	getKeys: func() {
		return [];
	},
	update: func() {
		var volt = getprop(volt_prop) or 0;
		var start = getprop(start_prop) or 0;
		if ( start == 1 and volt > 9) {
			tablet_main.page.show();
			tablet_map.show();
			tablet_main.update();
			tablet_start.page.hide();			
		} else if ( start > 0 and start < 1 and volt > 9 ){
			tablet_start.page.show();
			tablet_main.page.hide();
			tablet_map.hide();
		} else {
			tablet_start.page.hide();
			tablet_main.page.hide();
			tablet_map.hide();
		}
		
		settimer(func me.update(), 0.1);
	},
};
	


var canvas_tablet_main = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_tablet_main , canvas_tablet_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["time.utc","groundspeed","altitude","vertspeed","track","range","mapp"];
	},
	update: func() {
		me["time.utc"].setText(sprintf("%02d",getprop(time_base~"hour"))~":"~sprintf("%02d",getprop(time_base~"minute")));
		me["groundspeed"].setText(sprintf("%3d", math.round(getprop("/velocities/groundspeed-kt"))));
		me["altitude"].setText(sprintf("%5d", math.round(getprop("/position/altitude-ft"))));
		me["vertspeed"].setText(sprintf("%+4d", math.round((getprop("/velocities/vertical-speed-fps")/60)*1000)));
		me["track"].setText(sprintf("%3d", math.round(getprop("/orientation/track-deg")))~"°");
		# me["range"].setText(sprintf("%.1f", tablet_map._map-getRange()));
	}
	
};

var canvas_tablet_start = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_tablet_start , canvas_tablet_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["mapp"];
	},
	update: func() {
	}
	
};
var canvas_tablet_map = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_tablet_map , canvas_tablet_base] };
		m.init(canvas_group, file);
		m._map = me.page.createChild("map")
        .setTranslation(800,555)
        .setSize(1600, 1110);
		# .set("z-index", 150)
		m._map.setRange(10); 
		# m._map.set("clip-frame", canvas.Element.LOCAL);
		# m._map.set("clip", "1800, 1110");

		m._map.setController("Aircraft position");
		
		# m._map.setTranslation(
		# tablet_display.get("view[0]")/2,
		# tablet_display.get("view[1]")/2	
		# );
		var r = func(name,vis=1,zindex=nil) return caller(0)[0];
		var type = r('OSM',zindex=-1);
		m._map.addLayer(factory: canvas.OverlayLayer, type_arg: type.name,
													visible: type.vis, priority: type.zindex);
		foreach(var type; [ r('APT'), r('APS') ] )
		m._map.addLayer(factory: canvas.SymbolLayer, type_arg: type.name, visible: type.vis, priority: type.zindex,);
		return m;
	},
	getKeys: func() {
		return ["rangeup","rangedown"];
	},
	update: func() {
	}
	
};




var identoff = func {
	setprop("/instrumentation/transponder/inputs/ident-btn", 0);
}

setlistener("/instrumentation/transponder/inputs/ident-btn-2", func{
	setprop("/instrumentation/transponder/inputs/ident-btn", 1);
	settimer(identoff, 18);
});


setlistener("sim/signals/fdm-initialized", func {
	tablet_display = canvas.new({
		"name": "tablet",
		#"size": [800, 600],
		#"view": [960, 600],
	    "view": [1920, 1200],
		"size": [1920, 1200],
		# "size": [1224, 875],
		# "view": [1224, 875],
		"mipmapping": 1
	});
	tablet_display.addPlacement({"node": "tablet-screen"});
	var groupMap = tablet_display.createGroup("map");
	var groupMain = tablet_display.createGroup("main");
	var groupStart = tablet_display.createGroup("start");
	


	tablet_main = canvas_tablet_main.new(groupMain, instrument_dir~"tablet_main_portrait.svg");
	tablet_start = canvas_tablet_start.new(groupStart, instrument_dir~"tablet_start_portrait.svg");
	# tablet_map = canvas_tablet_map.new(groupMap, instrument_dir~"tablet_map_portrait.svg");
	#groupMap.setInt("z-index", 10.0);
	#groupMap.setSize(1024,1024);
	
	groupMap.setTranslation(200,0);
	tablet_map = groupMap.createChild("map");
	# print("size: ", tablet_map.getSize());
	# .setSize(1600, 1110);
	tablet_map.setRange(10); 
	tablet_map.setController("Aircraft position");
	# tablet_map.set("clip-frame", canvas.Element.LOCAL);
	# tablet_map.set("clip", "1110, 1110");
	# tablet_map.setTranslation(800,600);
    tablet_map.setTranslation(512,412);
	groupMap.setScale(1.5);
    
	
	var r = func(name,vis=1,zindex=nil) return caller(0)[0];
	var type = r('OSM',zindex=-1);
	tablet_map.addLayer(factory: canvas.OverlayLayer, type_arg: type.name,
												 visible: type.vis, priority: type.zindex);
	foreach(var type; [ r('APT'), r('APS') ] )
		tablet_map.addLayer(factory: canvas.SymbolLayer, type_arg: type.name, visible: type.vis, priority: type.zindex,);
	
	canvas_tablet_base.update();
	print("### Tablet loaded");
});


setlistener(volt_prop, func (i) {
	if( i.getValue() <= 9  and getprop(start_prop) != 0){
		setprop(start_prop, 0);
	}else if ( i.getValue() > 9 and getprop(start_prop) == 0){
		interpolate(start_prop, 1, 3);
	}
});

	
