###############################################################################
##
## Zeppelin LZ 121 "Nordstern" airship for FlightGear.
##
##  Copyright (C) 2010  Anders Gidenstam  (anders(at)gidenstam.org)
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
var static_trim_p = "/fdm/jsbsim/fcs/static-trim-cmd-norm";
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
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[15]"
    ];
var aft_ballast_p =
    [
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[0]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[1]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[2]",
     "/fdm/jsbsim/inertia/pointmass-weight-lbs[3]"
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

var mp_mast_carriers =
    ["Aircraft/ZLT-NT/Models/GroundCrew/scania-mast-truck.xml"];

var init_all = func(reinit=0) {
    setprop(static_trim_p, 0.5);
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
    }

    # Timed initialization.
    settimer(func {
        # Add some AI moorings.
        mooring.add_ai_mooring(props.globals.getNode("/ai/models/carrier[0]"),
                               160.0);
        mooring.add_ai_mooring(props.globals.getNode("/ai/models/carrier[1]"),
                               160.0);
        mooring.add_ai_mooring(props.globals.getNode("/ai/models/carrier[2]"),
                               160.0);
        setlistener(props.globals.getNode("/ai/models/model-added", 1),
                    func (path) {
                        var node = props.globals.getNode(path.getValue());
                        if (nil == node.getNode("sim/model/path")) return;
                        var model = node.getNode("sim/model/path").getValue();
                        foreach (var c; mp_mast_carriers) {
                            if (model == c) {
                                settimer(func {
                                  mooring.add_ai_mooring
                                    (node,
                                     "sim/model/mast-truck/mast-head-height-m");
                                  print("Added: " ~ path.getValue());
                                }, 0.0);
                                return;
                            }
                        }
                    });
        setlistener(props.globals.getNode("/ai/models/model-removed"),
                    func (path) {
                        var node = props.globals.getNode(path.getValue());
                        mooring.remove_ai_mooring(node);
                        #print("Removed: " ~ path.getValue());
                    });
    }, 1.0);
    print("Nordstern Systems ... Check");
}

setlistener("/sim/signals/fdm-initialized", func {
    init_all();
    setlistener("/sim/signals/reinit", func(reinit) {
        if (!reinit.getValue()) {
            init_all(reinit=1);
        }
    });
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
    var units = nil;
    if (location == FORE_BALLAST) {
        units = fore_ballast_p;
    } elsif (location == AFT_BALLAST) {
        units = aft_ballast_p;
    } else {
        printlog("warn",
                 "Nordstern.releaseBallast(" ~ location ~ ", " ~ amount ~
                 "): Invalid ballast location.");
        return;
    }
    foreach (var p; units) {
        if (!amount) return;
        if (getprop(p) > 0.0) {
            interpolate(p, 0.0, 1.0);
            amount -= 1;
        }
    }
}

# Refills empty "ballasthosen" from the trim ballast bags.
var refillQuickReleaseBallast = func(location) {
    var units = nil;
    if (location == FORE_BALLAST) {
        units = fore_ballast_p;
    } elsif (location == AFT_BALLAST) {
        units = aft_ballast_p;
    } else {
        printlog("warn",
                 "Nordstern.refillQuickReleaseBallast(" ~ location ~
                 ", " ~ amount ~
                 "): Invalid ballast location.");
        return;
    }
    var n = size(trim_ballast_p);
    foreach (var qb; units) {
        var v = getprop(qb);
        if (v < QUICK_RELEASE_BAG_CAPACITY) {
            foreach(var tb; trim_ballast_p) {
                SmoothTransfer.new(tb, qb,
                                   2.0,
                                   (QUICK_RELEASE_BAG_CAPACITY - v)/n);
            }
        }
    }
}

###############################################################################
# Gas valve controls
var gascell        = "/fdm/jsbsim/buoyant_forces/gas-cell";

var setForwardGasValves = func (v) {
    setprop(gascell ~ "[12]/valve_open", v);
    setprop(gascell ~ "[11]/valve_open", v);
}

var setAftGasValves = func (v) {
    setprop(gascell ~ "[1]/valve_open", v);
    setprop(gascell ~ "[0]/valve_open", v);
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
        me.left.add(static_trim_p);
        me.left.add("/fdm/jsbsim/mooring/total-distance-ft");
        # Pitch moments
        me.left.add("/fdm/jsbsim/moments/m-buoyancy-lbsft",
                    "/fdm/jsbsim/moments/m-aero-lbsft",
                    "/fdm/jsbsim/moments/m-total-lbsft");
       
        # Flight information
        me.right.add("orientation/pitch-deg");
        me.right.add("surface-positions/elevator-pos-norm");
        me.right.add("surface-positions/rudder-pos-norm");
        me.right.add("instrumentation/altimeter/indicated-altitude-ft");
        me.right.add("instrumentation/altimeter/indicated-altitude-ft");
        me.right.add("instrumentation/airspeed-indicator/indicated-speed-kt");
        # Engines
        me.right.add("/engines/engine[0]/rpm",
                     "/engines/engine[1]/rpm",
                     "/engines/engine[2]/rpm",
                     "/engines/engine[3]/rpm");

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
             "Copyright (C) 2010  Anders Gidenstam\n\n" ~
             "FlightGear flight simulator\n" ~
             "Copyright (C) 1997 - 2010  http://www.flightgear.org\n\n" ~
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
