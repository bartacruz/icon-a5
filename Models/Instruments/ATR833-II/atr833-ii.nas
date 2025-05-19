# Simulation of the F.U.N.K.E. ATR833-II COM by Bea Wolf (D-ECHO) based on

# A3XX Lower ECAM Canvas
# Joshua Davidson (it0uchpods)

#Information based on manual https://www.funkeavionics.de/wp-content/uploads/2020/07/01.143.010.71d_ATR833-II_OI-Rev1.05_180425_WEB-PRINT.pdf
#######################################

var ATR833_main = nil;
var ATR833_start = nil;
var ATR833_display = nil;

var base = "/instrumentation/airspeed-indicator/";
var inputs = base~"inputs/";

var ALT = props.globals.getNode("instrumentation/altimeter/indicated-altitude-ft", 1);
var ATR833_qnh = props.globals.getNode("instrumentation/altimeter/setting-hpa", 1);
var ATR833_fl = props.globals.getNode("instrumentation/altimeter/mode-c-alt-ft", 1);

var volts = props.globals.getNode("/systems/electrical/outputs/comm", 1);

var instrument_dir = "Aircraft/AlphaElectro/Models/Instruments/ATR833-II/";
var comm = props.globals.getNode("/instrumentation/comm[0]");
var base = props.globals.initNode("/instrumentation/atr833-ii");

var cursor_sel = base.initNode("cursor-selection", 0, "INT"); # currently only manipulates the standby frequency, 0 = off, 1 = mhz, 2 = 100 khz, 3 = 1 khz
setlistener( cursor_sel, func{ ATR833_main.update_cursor() } );

var current_sel = base.initNode("current-selection", 0, "INT");	# ref p. 17:	0 = VOL, 1 = SQL, 2 = VOX, 3 = INT, 4 = STL, 5 = STR, 6 = EXT, 7 = BRT
var setting_labels = [ "VOL", "SQL", "VOX", "INT", "STL", "STR", "EXT", "BRT" ];
var setting_values = [
	comm.initNode("volume", 0.5, "DOUBLE"),
	comm.initNode("squelch", 5, "INT"),
	comm.initNode("vox", 5, "INT"),
	comm.initNode("intercom-volume", 5, "INT"),
	comm.initNode("sidetone-volume[0]", 5, "INT"),
	comm.initNode("sidetone-volume[1]", 5, "INT"),
	comm.initNode("external-volume", 5, "INT"),
	comm.initNode("brightness", 5, "INT"),
];
var setting_listeners = [];

var tx = comm.getNode("ptt", 1);
var rx = comm.getNode("rx", 1);

var freq_act = comm.getNode("frequencies/selected-mhz", 1);
var freq_sby = comm.getNode("frequencies/standby-mhz",  1);

var time = props.globals.getNode("/sim/time/elapsed-sec", 1);

var state = 0;	# 0 = off, 1 = starting, 2 = on


var canvas_ATR833_base = {
	init: func(canvas_group, file) {
		var font_mapper = func(family, weight) {
			if( family == "OLED_5x14" ){
				return "OLED-5_14.ttf";
			} else {
				return "OLED-10_14.ttf";
			}
		};

		
		canvas.parsesvg(canvas_group, file, {'font-mapper': font_mapper});

		 var svg_keys = me.getKeys();
		 
		foreach (var key; svg_keys) {
			me[key] = canvas_group.getElementById(key);
			var clip_el = canvas_group.getElementById(key ~ "_clip");
			if (clip_el != nil) {
				clip_el.setVisible(0);
				var tran_rect = clip_el.getTransformedBounds();
				var clip_rect = sprintf("rect(%d,%d, %d,%d)", 
				tran_rect[1], # 0 ys
				tran_rect[2], # 1 xe
				tran_rect[3], # 2 ye
				tran_rect[0]); #3 xs
				#   coordinates are top,right,bottom,left (ys, xe, ye, xs) ref: l621 of simgear/canvas/CanvasElement.cxx
				me[key].set("clip", clip_rect);
				me[key].set("clip-frame", canvas.Element.PARENT);
			}
		}

		me.page = canvas_group;

		return me;
	},
	getKeys: func() {
		return [];
	},
	update: func() {
		
		if ( volts.getDoubleValue() > 10 ){
			if( state == 1 ) {
				ATR833_start.page.show();
				ATR833_main.page.hide();
			} elsif( state == 2 ){
				ATR833_start.page.hide();
				ATR833_main.page.show();
			} else {
				ATR833_start.page.hide();
				ATR833_main.page.hide();
			}
		} else {
			ATR833_start.page.hide();
			ATR833_main.page.hide();
			if( io_btn_start_time != nil ){ io_btn_start_time = nil; }
		}
	},
};

var canvas_ATR833_start = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_ATR833_start , canvas_ATR833_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return [];
	},
};
	
	
var canvas_ATR833_main = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_ATR833_main , canvas_ATR833_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["freq.act", "freq.sby", "act.flag", "setting_label", "setting_value", "cursor.sby.mhz", "cursor.sby.100khz", "cursor.sby.1khz"];
	},
	update_act_freq: func() {
		me["freq.act"].setText( sprintf("%6.3f", freq_act.getDoubleValue() ) );
	},
	update_sby_freq: func() {
		me["freq.sby"].setText( sprintf("%6.3f", freq_sby.getDoubleValue() ) );
	},
	update_settings: func() {
		# Settings Lable
		var cs = current_sel.getIntValue();
		me["setting_label"].setText( setting_labels[ cs ] );
		if( cs == 0 ){
			me["setting_value"].setText( sprintf("%2d", math.round( setting_values[0].getDoubleValue() * 20 ) ) );
		} else {
			me["setting_value"].setText( sprintf("%2d", setting_values[ cs ].getIntValue() ) );
		}
	},
	update_cursor: func() {
		var cursor_pos = cursor_sel.getIntValue();
		if( cursor_pos == 0 ){
			me["cursor.sby.mhz"].hide();
			me["cursor.sby.100khz"].hide();
			me["cursor.sby.1khz"].hide();
		} elsif( cursor_pos == 1 ){
			me["cursor.sby.mhz"].show();
			me["cursor.sby.100khz"].hide();
			me["cursor.sby.1khz"].hide();
		} elsif( cursor_pos == 2 ){
			me["cursor.sby.mhz"].hide();
			me["cursor.sby.100khz"].show();
			me["cursor.sby.1khz"].hide();
		} elsif( cursor_pos == 3 ){
			me["cursor.sby.mhz"].hide();
			me["cursor.sby.100khz"].hide();
			me["cursor.sby.1khz"].show();
		}
	},
	update_act_flag: func() {
		# TX/RX flag
		if( tx.getBoolValue() ){
			me["act.flag"].setText("TX");
		} elsif( rx.getBoolValue() ){
			me["act.flag"].setText("RX");
		} else {
			me["act.flag"].setText("");
		}
	},
	update: func() {
		me.update_act_freq();
		me.update_sby_freq();
		me.update_settings();
		me.update_cursor();
		me.update_act_flag();
	},
};

var io_btn_start_time = nil;

var io_btn = func( a ){
	if( a and volts.getDoubleValue() >= 10 ){
		io_btn_start_time = time.getDoubleValue();
		if( state == 0 ){
			settimer( func io_btn(0), 0.55 );
		} else {
			settimer( func io_btn(0), 3.05 );
		}
	} else {
		if( io_btn_start_time == nil ){ return; }
		var time_diff = time.getDoubleValue() - io_btn_start_time;
		if( state == 0 and time_diff > 0.5 ){
			state = 1;
			settimer( func{ state = 2 }, 2.0 );
		} elsif( state > 0 and time_diff > 3.0 ){
			state = 0;
		}
		io_btn_start_time = nil;
	}
}

var base_updater = maketimer( 0.5, canvas_ATR833_base.update );
base_updater.simulatedTime = 1;


var ls = setlistener("sim/signals/fdm-initialized", func {
	removelistener( ls );
	ATR833_display = canvas.new({
		"name": "atr833_ii",
		"size": [256, 128],	# twice the real resolution is necessary to render the font well
		"view": [128, 64],
		"mipmapping": 1
	});
	ATR833_display.addPlacement({"node": "atr833.display"});
	var groupMain = ATR833_display.createGroup();
	var groupStart = ATR833_display.createGroup();



	ATR833_start = canvas_ATR833_start.new(groupStart, instrument_dir~"atr833-ii-start.svg");
	ATR833_main = canvas_ATR833_main.new(groupMain, instrument_dir~"atr833-ii-main.svg");
	
	
	foreach( var el; setting_values ){
		append(setting_listeners, setlistener( el, func{ ATR833_main.update_settings(); } ));
	}
	setlistener( current_sel, func{ ATR833_main.update_settings(); } );
	setlistener( tx, func{ ATR833_main.update_act_flag(); } );
	setlistener( rx, func{ ATR833_main.update_act_flag(); } );
	setlistener( freq_act, func{ ATR833_main.update_act_freq(); } );
	setlistener( freq_sby, func{ ATR833_main.update_sby_freq(); } );
	
	ATR833_main.update();
	base_updater.start();
});
