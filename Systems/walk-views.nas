###############################################################################
##
## Zeppelin LZ 121 "Nordstern" airship for FlightGear.
## Walk view configuration.
##
##  Copyright (C) 2010 - 2025  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

# Constraints
var carConstraint =
    walkview.makeUnionConstraint(
        [
         walkview.SlopingYAlignedPlane.new([20.3, -0.5, -10.8], # Extreme ends
                                           [23.5,  0.5, -10.8]),
         walkview.SlopingYAlignedPlane.new([38.3, -0.5, -11.1],
                                           [43.0,  0.5, -11.2]),
         
         walkview.SlopingYAlignedPlane.new([23.4, -0.0, -10.8], # Rooms
                                           [24.8,  1.3, -10.9]),
         walkview.SlopingYAlignedPlane.new([25.2, -1.3, -10.9],
                                           [29.8,  1.3, -10.9]),
         walkview.SlopingYAlignedPlane.new([30.1, -1.3, -10.9],
                                           [34.8,  1.3, -11.0]),
         walkview.SlopingYAlignedPlane.new([35.1, -1.3, -11.0],
                                           [37.4,  1.3, -11.1]),
         
         walkview.SlopingYAlignedPlane.new([23.4, -0.05, -10.8], # Doorways
                                           [38.3,  0.62, -11.1]),
        ]);

var keelConstraint =
    walkview.makeUnionConstraint(
        [
         walkview.makePolylinePath(
             [
              [ 10.0,  0.0,  -6.3],
              [ 15.0,  0.0,  -7.2],
              [ 20.0,  0.0,  -7.8],
              [ 25.0,  0.0,  -8.2],
              [ 30.0,  0.0,  -8.6],
              [ 35.0,  0.0,  -8.8],
              [ 40.0,  0.0,  -9.0],
              [ 50.0,  0.0,  -9.1],
              [ 65.0,  0.0,  -9.1],
              [ 70.0,  0.0,  -8.8],
              [ 80.0,  0.0,  -8.5],
              [ 90.0,  0.0,  -7.9],
              [ 95.0,  0.0,  -7.4],
              [100.0,  0.0,  -6.9],
              [105.0,  0.0,  -6.2],
              [110.0,  0.0,  -5.4],
             ],
             0.20),
         walkview.makePolylinePath(
             [
              [ 59.75, -4.90, -7.79],
              [ 59.75, -1.70, -9.05],
              [ 59.75,  1.70, -9.05],
              [ 59.75,  4.90, -7.79],
             ],
             0.20)
        ]);

var ladderPosition = [22.7, -0.45, 0.0];

var climbLadder = func {
    var walker = walkview.active_walker();
    if (walker != nil) {
        var p = walker.get_pos();
        if (math.abs(p[0] - ladderPosition[0]) < 0.5 and
            math.abs(p[1] - ladderPosition[1]) < 0.5) {
            
            if (walker.get_constraints() == keelConstraint) {
                walker.set_constraints(carConstraint);
            } else {
                walker.set_constraints(keelConstraint);
            }
        }
    }
}

# ThreeDModel manager.
#   Moves a 3d model representing the crew member together with the view.
#   The position is in the main 3d coordinate system.
# CONSTRUCTOR:
#       ThreeDModel.new(name, maximumMoveValue);
#
#         name             ... Name of the view : string
#         maximumMoveValue ... Maximum movement of the view i meters : double
#
var ThreeDModelManager = {
    new : func (name, maximumMoveValue) {
        var base = props.globals.getNode("crew/" ~ name ~ "/");
        var prefix  = "position-";
        var postfix = "-m";
        var obj = { parents : [ThreeDModelManager] };
        obj.pos_m =
            [
             base.getNode(prefix ~ "X" ~ postfix),
             base.getNode(prefix ~ "Y" ~ postfix),
             base.getNode(prefix ~ "Z" ~ postfix)
            ];
        obj.maximumMoveValue = maximumMoveValue;
        base.getNode("maximum-move-m").setValue(obj.maximumMoveValue);
        postfix = "-norm";
        obj.pos_norm =
            [
             base.getNode(prefix ~ "X" ~ postfix),
             base.getNode(prefix ~ "Y" ~ postfix),
             base.getNode(prefix ~ "Z" ~ postfix)
            ];
        postfix = "-offset-deg";
        obj.orientation_deg =
            [
             base.getNode("heading" ~ postfix),
             base.getNode("pitch" ~ postfix),
            ];
        return obj;
    },
    update : func (walker) {
        # Position.
        var pos = walker.get_pos();
        me.pos_m[0].setValue(pos[0]);
        me.pos_m[1].setValue(pos[1]);
        me.pos_m[2].setValue(pos[2] - walker.get_eye_height());
        # Normalized position.
        me.pos_norm[0].setValue(pos[0]/me.maximumMoveValue);
        me.pos_norm[1].setValue(pos[1]/me.maximumMoveValue);
        me.pos_norm[2].setValue((pos[2] - walker.get_eye_height())/me.maximumMoveValue);
        # Orientation is not yet stored in the walker but is stored in the view.
        me.orientation_deg[0].setValue(
            props.globals.getNode("/sim/current-view/heading-offset-deg").getValue());
        me.orientation_deg[1].setValue(
            props.globals.getNode("/sim/current-view/pitch-offset-deg").getValue());
    }
};

# Create the view managers.
var steward_walker =
    walkview.Walker.new("Steward View",
                        carConstraint,
                        [walkview.JSBSimPointmass.new(29),
                         ThreeDModelManager.new("steward-view", 100.0)]);
steward_walker.managers[1].update(steward_walker); # Place the 3d object.

var rigger_walker =
    walkview.Walker.new("Rigger View",
                        keelConstraint,
                        [walkview.JSBSimPointmass.new(30),
                         ThreeDModelManager.new("rigger-view", 100.0)]);
rigger_walker.managers[1].update(rigger_walker); # Place the 3d object.

var watch_officer_walker =
    walkview.Walker.new("Watch Officer View",
                        carConstraint,
                        [walkview.JSBSimPointmass.new(26),
                         ThreeDModelManager.new("watch-officer-view", 100.0)]);
watch_officer_walker.managers[1].update(watch_officer_walker); # Place the 3d object.

