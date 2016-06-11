###############################################################################
##
## Zeppelin LZ 121 "Nordstern" airship for FlightGear.
##
##  Copyright (C) 2010 - 2016  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

###############################################################################
# External API
#
# autoWeightOff()
# printWOW()
# shiftTrimBallast(direction, amount)
# releaseBallast(location, amount)
# refillQuickReleaseBallast(location)
# setForwardGasValves()
# setAftGasValves()
# switchEngineDirection(engine)
# about()
#

# Constants
var FORWARD = -1;
var AFT     = -2;
var FORE_BALLAST = -1;
var AFT_BALLAST = -2;
var QUICK_RELEASE_BAG_CAPACITY = 220.5; # lb
var TRIM_BAG_CAPACITY = 1102.3; # lb

###############################################################################
var weight_on_gear_p = "/fdm/jsbsim/forces/fbz-gear-lbs";

var trim_ballast_p =
    [
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[4]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[5]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[6]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[7]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[8]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[9]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[10]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[11]"
    ];
var fore_ballast_p =
    [
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[12]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[13]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[14]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[15]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[16]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[17]"
    ];
var fore_ballast_toggles_p =
    [
     "/controls/ballast/release[0]",
     "/controls/ballast/release[1]",
     "/controls/ballast/release[2]",
     "/controls/ballast/release[3]",
     "/controls/ballast/release[4]",
     "/controls/ballast/release[5]",
    ];
var aft_ballast_p =
    [
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[0]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[1]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[2]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[3]"
    ];
var aft_ballast_toggles_p =
    [
     "/controls/ballast/release[6]",
     "/controls/ballast/release[7]",
     "/controls/ballast/release[8]",
     "/controls/ballast/release[9]"
    ];

var printWOW = func {
    gui.popupTip("Current weight on gear " ~
                 -getprop(weight_on_gear_p) ~ " lbs.");
}

# Weight off to neutral
var autoWeighoff = func {
    var lift = getprop("/fdm/jsbsim/static-condition/net-lift-lbs");
    var n = size(trim_ballast_p);
        
    print("Nordstern: Auto weigh off from " ~ (-lift) ~
          " lb heavy to neutral.");

    foreach(var p; trim_ballast_p) {
        var v = getprop(p) + lift/n;
        interpolate(p,
                    (v > 0 ? v : 0),
                    0.5);
        #n -= 1;
        #lift -= (v > 0 ? v : 0);
    }
}

var initial_weighoff = func {
    # Set initial static condition.
    # Finding the right static condition at initialization time is tricky.
    autoWeighoff();
    settimer(autoWeighoff, 0.25);
    settimer(autoWeighoff, 1.0);
    # Fill up the envelope if not at pressure already. A bit of a hack.
#    settimer(func {
#        setprop("/fdm/jsbsim/buoyant_forces/gas-cell/contents-mol",
#                2.0 *
#                getprop("/fdm/jsbsim/buoyant_forces/gas-cell/contents-mol"));
#    }, 0.8);
}

var init_all = func(reinit=0) {
    initial_weighoff();

#    fake_electrical();
    # Disable the autopilot menu.
    gui.menuEnable("autopilot", 0);

    if (!reinit) {
        # Hobbs counters.
#        aircraft.timer.new("/sim/time/hobbs/engine[0]", 73).start();
#        aircraft.timer.new("/sim/time/hobbs/engine[0]", 73).start();
#        aircraft.timer.new("/sim/time/hobbs/engine[0]", 73).start();
        # Livery support.
#        aircraft.livery.init("Aircraft/ZLT-NT/Models/Liveries")

        # Create FG /controls/gas/ aliases for FDM owned controls.
        var fdm = "fdm/jsbsim/buoyant_forces/gas-cell";
        props.globals.getNode(gascell ~ "[0]", 1).
            alias(props.globals.getNode(fdm ~ "[11]/valve_open"));
        props.globals.getNode(gascell ~ "[1]", 1).
            alias(props.globals.getNode(fdm ~ "[10]/valve_open"));
        props.globals.getNode(gascell ~ "[2]", 1).
            alias(props.globals.getNode(fdm ~ "[1]/valve_open"));
        props.globals.getNode(gascell ~ "[3]", 1).
            alias(props.globals.getNode(fdm ~ "[0]/valve_open"));
    }

    # Add some AI moorings.
    if (!reinit) {
        # Timed initialization.
        settimer(func {
            # Add some AI moorings.
            foreach (var c;
                     props.globals.getNode("/ai/models").
                         getChildren("carrier")) {
                mooring.add_ai_mooring(c, 160.0);
            }
        }, 0.0);
    }
    print("Nordstern Systems ... Check");
}

var _nordstern_initialized = 0;
setlistener("/sim/signals/fdm-initialized", func {
    init_all(_nordstern_initialized);
    _nordstern_initialized = 1;
});

###############################################################################
# Ballast controls

var shiftTrimBallast = func(direction, amount) {
    var from = nil;
    var to = nil;
    if (direction == FORWARD) {
        from = [trim_ballast_p[0], trim_ballast_p[1]];
        to   = [trim_ballast_p[6], trim_ballast_p[7]];
    } elsif (direction == AFT) {
        from = [trim_ballast_p[6], trim_ballast_p[7]];
        to   = [trim_ballast_p[0], trim_ballast_p[1]];

    } else {
        printlog("warn",
                 "Nordstern.shiftTrimBallast(" ~ direction ~ ", " ~ amount ~
                 "): Invalid direction.");
        return;
    }
    foreach (var p; from) {
        SmoothTransfer.new(p, to[0],
                           2.0,
                           0.25*amount);
        SmoothTransfer.new(p, to[1],
                           2.0,
                           0.25*amount);
    }
}

# Release one or more quick-release ballast units.
var releaseBallast = func(location, amount) {
    var units   = nil;
    var toggles = nil;
    if (location == FORE_BALLAST) {
        units   = fore_ballast_p;
        toggles = fore_ballast_toggles_p;
    } elsif (location == AFT_BALLAST) {
        units   = aft_ballast_p;
        toggles = aft_ballast_toggles_p;
    } else {
        printlog("warn",
                 "Nordstern.releaseBallast(" ~ location ~ ", " ~ amount ~
                 "): Invalid ballast location.");
        return;
    }
    forindex (var i; units) {
        if (!amount) return;
        if (getprop(units[i]) > 0.0) {
            #interpolate(units[i], 0.0, 1.0);
            setprop(toggles[i], 1.0);
            amount -= 1;
        }
    }
}

# Refills empty "ballasthosen" from the trim ballast bags.
var refillQuickReleaseBallast = func(location) {
    var units   = nil;
    var toggles = nil;
    if (location == FORE_BALLAST) {
        units   = fore_ballast_p;
        toggles = fore_ballast_toggles_p;
    } elsif (location == AFT_BALLAST) {
        units   = aft_ballast_p;
        toggles = aft_ballast_toggles_p;
    } else {
        printlog("warn",
                 "Nordstern.refillQuickReleaseBallast(" ~ location ~
                 ", " ~ amount ~
                 "): Invalid ballast location.");
        return;
    }
    var n = size(trim_ballast_p);
    forindex (var qb; units) {
        var v = getprop(units[qb]);
        if (v < QUICK_RELEASE_BAG_CAPACITY) {
            setprop(toggles[qb], 0.0);
            foreach(var tb; trim_ballast_p) {
                SmoothTransfer.new(tb, units[qb],
                                   2.0,
                                   (QUICK_RELEASE_BAG_CAPACITY - v)/n);
            }
        }
    }
}

# Listen to the /controls/ballast/release[x] controls.
forindex(var i; fore_ballast_toggles_p) {
    setlistener(fore_ballast_toggles_p[i], func (n) {
        interpolate(fore_ballast_p[n.getIndex()], 0.0, 1.0);
    }, 0, 0);
}
forindex(var i; aft_ballast_toggles_p) {
    setlistener(aft_ballast_toggles_p[i], func (n) {
        interpolate(aft_ballast_p[n.getIndex() - size(fore_ballast_toggles_p)],
                    0.0, 1.0);
    }, 0, 0);
}


###############################################################################
# Gas valve controls
var gascell = "controls/gas/valve-cmd-norm";

var setForwardGasValves = func (v) {
    setprop(gascell ~ "[0]", v);
    setprop(gascell ~ "[1]", v);
}

var setAftGasValves = func (v) {
    setprop(gascell ~ "[2]", v);
    setprop(gascell ~ "[3]", v);
}


###############################################################################
# Engine controls.
var switchEngineDirection = func (eng) {
    var engineJSB = "/fdm/jsbsim/propulsion/engine" ~ "[" ~ eng ~ "]";
    var engineFG  = "/engines/engine" ~ "[" ~ eng ~ "]";
    var dir       = engineJSB ~ "/yaw-angle-rad";

    # Only engine 0 and 1 can be reversed.
    if ((eng < 0) or (eng > 1)) return;

    if (!getprop(engineFG ~ "/running")) {
        setprop(dir, (getprop(dir) == 0) ? 3.14159265 : 0.0);
        # NOTE: The popup tip should probably be at the callers discretion. 
        gui.popupTip("Engine " ~ eng ~
                     " set to " ~
                     ((getprop(dir) == 0) ? "forward." : "reverse."));
    } else {
        # NOTE: The popup tip should probably be at the callers discretion. 
        gui.popupTip("Cannot change direction for " ~
                     ((getprop(dir) == 0) ? "forward" : "reverse") ~
                     " running engine " ~ eng ~ ".");
    }
}

###############################################################################
# Utility functions

# Set up aTransfer fluid between two properties without losing or creating any.
#  amount [lb]
#  rate   [lb/sec]
var SmoothTransfer = {
    # Set up a smooth value transfer between two properties.
    #  from, to       : property paths or property nodes
    #  rate           : units/sec. MUST be positive.
    #  amount         : the amount to transfer. MUST be positive.
    #  stop_at_zero   : stop if the from property reaches 0.0.
    new: func(from, to, rate, amount=-1, stop_at_zero=1) {
        var m = { parents: [SmoothTransfer] };
        m.from         = aircraft.makeNode(from);
        m.to           = aircraft.makeNode(to);
        m.left         = amount;
        m.rate         = rate;
        m.stop_at_zero = stop_at_zero;
        m.last_time    = getprop("/sim/time/elapsed-sec");
        settimer(func{ m._loop_(); }, 0.0);
        return m;
    },
    stop: func {
        me.left = 0.0;
    },
    _loop_: func() {
        var t = getprop("/sim/time/elapsed-sec");
        var a = me.rate * (t - me.last_time);
        a = (a < me.left) ? a : me.left;
        if (me.stop_at_zero) {
            var f = me.from.getValue();
            a = (a < f) ? a : f;
        }
        me.from.setValue(f - a);
        me.to.setValue(me.to.getValue() + a);
        me.left -= a;
        me.last_time = t;
        if (me.left > 0.0) {
            settimer(func{ me._loop_(); }, 0.0);
        }
    }
};


###############################################################################
# Debug display - stand in instrumentation.
var debug_display_view_handler = {
    init : func {
        if (contains(me, "left")) return;

        me.left  = screen.display.new(20, 10);
        me.right = screen.display.new(-250, 20);
        # Static condition
        me.left.add("/fdm/jsbsim/static-condition/net-lift-lbs");
        me.left.add("/fdm/jsbsim/atmosphere/T-R");
        me.left.add("/fdm/jsbsim/buoyant_forces/gas-cell[1]/temp-R",
                    "/fdm/jsbsim/buoyant_forces/gas-cell[10]/temp-R");
        # C.G.
        me.left.add("/fdm/jsbsim/inertia/cg-x-in");
        # Pitch moments
        me.left.add("/fdm/jsbsim/moments/m-buoyancy-lbsft",
                    "/fdm/jsbsim/moments/m-aero-lbsft",
                    "/fdm/jsbsim/moments/m-total-lbsft");
        # Mooring related
        me.left.add("/fdm/jsbsim/mooring/total-distance-ft",
                    "/fdm/jsbsim/mooring/latitude-diff-ft",
                    "/fdm/jsbsim/mooring/longitude-diff-ft",
                    "/fdm/jsbsim/mooring/altitude-diff-ft");
        me.left.add("/fdm/jsbsim/velocities/vrp-v-north-fps",
                    "/velocities/speed-north-fps");
        me.left.add("/fdm/jsbsim/velocities/vrp-v-east-fps",
                    "/velocities/speed-east-fps");
        me.left.add("/fdm/jsbsim/velocities/vrp-v-down-fps",
                    "/velocities/speed-down-fps");

        # Flight information
        me.right.add("orientation/pitch-deg");
        me.right.add("surface-positions/elevator-pos-norm");
        me.right.add("surface-positions/rudder-pos-norm");
        me.right.add("instrumentation/altimeter/indicated-altitude-ft");
        me.right.add("instrumentation/airspeed-indicator/indicated-speed-kt");
        # Engines
        me.right.add("/engines/engine[0]/rpm",
                     "/fdm/jsbsim/propulsion/engine[0]/power-hp",
                     "/engines/engine[1]/rpm",
                     "/fdm/jsbsim/propulsion/engine[1]/power-hp",
                     "/engines/engine[2]/rpm",
                     "/fdm/jsbsim/propulsion/engine[2]/power-hp",
                     "/engines/engine[3]/rpm",
                     "/fdm/jsbsim/propulsion/engine[3]/power-hp");

        me.shown = 1;
        me.stop();
    },
    start  : func {
        if (!me.shown) {
            me.left.toggle();
            me.right.toggle();
        }
        me.shown = 1;
    },
    stop   : func {
        if (me.shown) {
            me.left.toggle();
            me.right.toggle();
        }
        me.shown = 0;
    }
};

# Install the debug display for some views.
setlistener("/sim/signals/fdm-initialized", func {
    view.manager.register("Watch Officer View", debug_display_view_handler);
    view.manager.register("Rudder Man View", debug_display_view_handler);
    view.manager.register("Elevator Man View", debug_display_view_handler);
    print("Debug instrumentation ... check");
});

###############################################################################
# fake part of the electrical system.
var fake_electrical = func {
#    setprop("systems/electrical/ac-volts", 24);
#    setprop("systems/electrical/volts", 24);

#    setprop("/systems/electrical/outputs/comm[0]", 24.0);
#    setprop("/systems/electrical/outputs/comm[1]", 24.0);
#    setprop("/systems/electrical/outputs/nav[0]", 24.0);
#    setprop("/systems/electrical/outputs/nav[1]", 24.0);
#    setprop("/systems/electrical/outputs/dme", 24.0);
#    setprop("/systems/electrical/outputs/adf", 24.0);
#    setprop("/systems/electrical/outputs/transponder", 24.0);
#    setprop("/systems/electrical/outputs/instrument-lights", 24.0);
#    setprop("/systems/electrical/outputs/gps", 24.0);
#    setprop("/systems/electrical/outputs/efis", 24.0);

#    setprop("/instrumentation/clock/flight-meter-hour",0);

    var beacon_switch =
        props.globals.initNode("controls/lighting/beacon", 1, "BOOL");
    var beacon = aircraft.light.new("sim/model/lights/beacon",
                                    [0.05, 1.2],
                                    "/controls/lighting/beacon");
    var strobe_switch =
        props.globals.initNode("controls/lighting/strobe", 1, "BOOL");
    var strobe = aircraft.light.new("sim/model/lights/strobe",
                                    [0.05, 3],
                                    "/controls/lighting/strobe");
}
###############################################################################

###########################################################################
## MP integration of user's fixed local mooring locations.
## NOTE: Should this be here or elsewhere?
settimer(func { mp_network_init(1); }, 0.1);

###############################################################################
# About dialog.

var ABOUT_DLG = 0;

var dialog = {
#################################################################
    init : func (x = nil, y = nil) {
        me.x = x;
        me.y = y;
        me.bg = [0, 0, 0, 0.3];    # background color
        me.fg = [[1.0, 1.0, 1.0, 1.0]]; 
        #
        # "private"
        me.title = "About";
        me.dialog = nil;
        me.namenode = props.Node.new({"dialog-name" : me.title });
    },
#################################################################
    create : func {
        if (me.dialog != nil)
            me.close();

        me.dialog = gui.Widget.new();
        me.dialog.set("name", me.title);
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);

        var titlebar = me.dialog.addChild("group");
        titlebar.set("layout", "hbox");
        titlebar.addChild("empty").set("stretch", 1);
        titlebar.addChild("text").set
            ("label",
             "About");
        var w = titlebar.addChild("button");
        w.set("pref-width", 16);
        w.set("pref-height", 16);
        w.set("legend", "");
        w.set("default", 0);
        w.set("key", "esc");
        w.setBinding("nasal", "ZLTNT.dialog.destroy(); ");
        w.setBinding("dialog-close");
        me.dialog.addChild("hrule");

        var content = me.dialog.addChild("group");
        content.set("layout", "vbox");
        content.set("halign", "center");
        content.set("default-padding", 5);
        props.globals.initNode("sim/about/text",
             "Zeppelin LZ 121 \"Nordstern\" airship for FlightGear\n" ~
             "Copyright (C) 2010 - 2016  Anders Gidenstam\n\n" ~
             "FlightGear flight simulator\n" ~
             "Copyright (C) 1996 - 2016  http://www.flightgear.org\n\n" ~
             "This is free software, and you are welcome to\n" ~
             "redistribute it under certain conditions.\n" ~
             "See the GNU GENERAL PUBLIC LICENSE Version 2 for the details.",
             "STRING");
        var text = content.addChild("textbox");
        text.set("halign", "fill");
        #text.set("slider", 20);
        text.set("pref-width", 400);
        text.set("pref-height", 300);
        text.set("editable", 0);
        text.set("property", "sim/about/text");

        #me.dialog.addChild("hrule");

        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.namenode);
    },
#################################################################
    close : func {
        fgcommand("dialog-close", me.namenode);
    },
#################################################################
    destroy : func {
        ABOUT_DLG = 0;
        me.close();
        delete(gui.dialog, "\"" ~ me.title ~ "\"");
    },
#################################################################
    show : func {
        if (!ABOUT_DLG) {
            ABOUT_DLG = 1;
            me.init(400, getprop("/sim/startup/ysize") - 500);
            me.create();
        }
    }
};
###############################################################################

# Popup the about dialog.
var about = func {
    dialog.show();
}
