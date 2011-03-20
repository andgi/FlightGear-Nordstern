###############################################################################
##
## Zeppelin LZ 121 "Nordstern" airship for FlightGear.
## Walk view configuration.
##
##  Copyright (C) 2010 - 2011  Anders Gidenstam  (anders(at)gidenstam.org)
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

# Create the view managers.
var steward_walker = walkview.Walker.new("Steward View",
                                         carConstraint,
                                         [walkview.JSBSimPointmass.new(29)]);
var rigger_walker = walkview.Walker.new("Rigger View",
                                        keelConstraint,
                                        [walkview.JSBSimPointmass.new(30)]);


