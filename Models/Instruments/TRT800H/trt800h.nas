# Simulation of the F.U.N.K.E. TRT800H XPDR by Bea Wolf (D-ECHO) based on

# A3XX Lower ECAM Canvas
# Joshua Davidson (it0uchpods)

#Information based on manual https://www.funkeavionics.de/wp-content/uploads/2021/03/03.2126.010.71d_TRT800H_1DS-LCDOLED-MS-FAA_OI_Rev3.00_210315_WEB.pdf
#######################################

var TRT800H_main = nil;
var TRT800H_start = nil;
var TRT800H_display = nil;

var volts = props.globals.getNode("/systems/electrical/outputs/transponder", 1);

var instrument_dir = "Aircraft/AlphaElectro/Models/Instruments/TRT800H/";
var xpdr = props.globals.getNode("/instrumentation/transponder");

var cursor_sel = xpdr.initNode("cursor-selection", 0, "INT"); # 0 = off, 1 = first digit, 2 = second digit, 3 = third digit, 4 = last digit
setlistener( cursor_sel, func{ TRT800H_main.update_cursor() } );

var idt = xpdr.getNode("ident", 1);

setlistener( idt, func{ TRT800H_main.update_idt_flag(); } );

var altitude = xpdr.getNode("altitude", 1);

setlistener( altitude, func{ TRT800H_main.update_altitude(); } );

var squawk_act = xpdr.getNode("id-code", 1);
var squawk_act_input = [
	xpdr.getNode("inputs/digit[3]", 1),
	xpdr.getNode("inputs/digit[2]", 1),
	xpdr.getNode("inputs/digit[1]", 1),
	xpdr.getNode("inputs/digit[0]", 1),
];
var squawk_sby = xpdr.initNode("id-code-sby",  7000, "INT");

setlistener( squawk_act, func{ TRT800H_main.update_act_squawk(); } );
setlistener( squawk_sby, func{ TRT800H_main.update_sby_squawk(); } );

var mode = xpdr.getNode("inputs/knob-mode", 1);

setlistener( mode, func{ TRT800H_main.update_mode(); } );

var time = props.globals.getNode("/sim/time/elapsed-sec", 1);

var state = 0;	# 0 = off, 1 = starting, 2 = on


var canvas_TRT800H_base = {
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
				TRT800H_start.page.show();
				TRT800H_main.page.hide();
			} elsif( state == 2 ){
				TRT800H_start.page.hide();
				TRT800H_main.page.show();
			} else {
				TRT800H_start.page.hide();
				TRT800H_main.page.hide();
			}
		} else {
			TRT800H_start.page.hide();
			TRT800H_main.page.hide();
			if( io_btn_start_time != nil ){ io_btn_start_time = nil; }
		}
	},
};

var canvas_TRT800H_start = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_TRT800H_start , canvas_TRT800H_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return [];
	},
};
	
	
var canvas_TRT800H_main = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_TRT800H_main , canvas_TRT800H_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["squawk.act", "squawk.sby", "mode.act", "mode.sby", "idt.flag", "flight_level"];
	},
	update_act_squawk: func() {
		if( squawk_act.getValue() != nil ){
			me["squawk.act"].setText( sprintf("%04d", squawk_act.getIntValue() ) );
		}
	},
	update_sby_squawk: func() {
		me["squawk.sby"].setText( sprintf("%04d", squawk_sby.getIntValue() ) );
	},
	update_mode: func() {
		var m = mode.getIntValue();
		if( m <= 2 ){
			me["mode.sby"].show();
			me["mode.act"].hide();
		} elsif( m <= 4 ){
			me["mode.sby"].hide();
			me["mode.act"].show();
			me["mode.act"].setText("A S");
		} elsif( m == 5 ){
			me["mode.sby"].hide();
			me["mode.act"].show();
			me["mode.act"].setText("ACS");
		}
	},
	update_cursor: func() {
		var cursor_pos = cursor_sel.getIntValue();
		screen.log.write( cursor_pos );
	},
	update_altitude: func() {
	},
	update_idt_flag: func() {
		if( idt.getBoolValue() ){
			me["idt.flag"].show();
		} else {
			me["idt.flag"].hide();
		}
	},
	update: func() {
		me.update_act_squawk();
		me.update_sby_squawk();
		me.update_idt_flag();
	},
};

var io_btn_start_time = nil;

var io_btn = func( a ){
	if( a and volts.getDoubleValue() >= 10 ){
		io_btn_start_time = time.getDoubleValue();
		if( state == 0 ){
			mode.setIntValue( 1 );
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

var swap_btn = func {
	cursor_sel.setIntValue( 0 );
	
	var temp_squawk = squawk_sby.getIntValue();
	squawk_sby.setIntValue( squawk_act.getIntValue() );
	
	squawk_act_input[0].setIntValue( math.floor( temp_squawk / 1000 ) );
	squawk_act_input[1].setIntValue( math.floor( math.mod( temp_squawk, 1000 ) / 100 ) );
	squawk_act_input[2].setIntValue( math.floor( math.mod( temp_squawk, 100 )  / 10 ) );
	squawk_act_input[3].setIntValue( math.floor( math.mod( temp_squawk, 10 )   / 1 ) );
}

var base_updater = maketimer( 0.5, canvas_TRT800H_base.update );
base_updater.simulatedTime = 1;


var ls = setlistener("sim/signals/fdm-initialized", func {
	removelistener( ls );
	TRT800H_display = canvas.new({
		"name": "trt800h",
		"size": [256, 128],	# twice the real resolution is necessary to render the font well
		"view": [128, 64],
		"mipmapping": 1
	});
	TRT800H_display.addPlacement({"node": "trt800h.display"});
	var groupMain = TRT800H_display.createGroup();
	var groupStart = TRT800H_display.createGroup();



	TRT800H_start = canvas_TRT800H_start.new(groupStart, instrument_dir~"trt800h-start.svg");
	TRT800H_main = canvas_TRT800H_main.new(groupMain, instrument_dir~"trt800h-main.svg");
	TRT800H_main.update();
	base_updater.start();
});
