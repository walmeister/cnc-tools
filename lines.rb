require 'rvg/rvg'
include Magick

# taken from tut https://rmagick.github.io/rvgtut.html

# The idea is to manually generate gcode to cut a gear for a quadcopter replacement
# Visualize the cutter movements and generate the gcode to cut it


# PROMBLEMS
# - Do the gcode and worry about visualizing later

# TODO:
# Add z positions to the gcode, and number of cuts
# - Add a way to visualize the cutter movements from the gcode
# - Add operations to mill the hub and crown, then the teeth

def from_polar(r, theta)
  [r * Math.cos(theta), r * Math.sin(theta)]
end

RVG::dpi = 72

def cut_circular_pocket(canvas, zoom, gcode, cx, cy, r1, r2, stepover_factor, tool_diam, depth, depth_of_cut)
  # calculate the number of cuts
  r1_start = r1 + 0.5 * tool_diam * zoom
  r2_end = r2 - 0.5 * tool_diam * zoom
  width_of_cut = r2 - r1 #r2 - r1_start # r2_end - r1_start
  step_over_distance = tool_diam * zoom * stepover_factor
  num_cuts = width_of_cut / step_over_distance
  puts "num_cuts: #{num_cuts}"
  num_cuts = num_cuts.to_i
  puts "num_cuts: #{num_cuts}"
  radius = r1_start
  num_cuts.times do |i|
    if radius > r2_end
      puts "radius: #{radius} > r2_end: #{r2_end}"
      break
    end
    canvas.circle(radius, cx, cy).styles(:stroke=>'green', fill: 'none')
    # gcode
    gcode << "G1 X#{(cx + radius).round(3)} Y#{(cy).round(3)}" # move to start
    gcode << "G3 I#{-(radius).round(3)} J0" # complete counter clockwise circle

    radius += step_over_distance
  end
  # last circle at correct radius
  canvas.circle(r2_end, cx, cy).styles(:stroke=>'yellow', fill: 'none')
  # gcode
  gcode << "G1 X#{(cx + r2_end).round(3)} Y#{(cy).round(3)}" # move to start
  gcode << "G3 I#{-(r2_end).round(3)} J0" # complete counter clockwise circle
end

# define the gear
zoom = 10.0  # !!! change 1 to 10 to view zoomed in
gear_radius = zoom * 15.2 / 2.0 # Outer radius in mm
gear_width = zoom * 1.0 # mm - original was only 0.7mm
gear_radius_innner = gear_radius - gear_width # Inner radius in mm
crown_height = 2.5 # mm
gear_base_height = 1.5 # mm
hub_height = 6.25 # mm
hub_radius = zoom * 4.0 / 2 # mm
hub_radius_inner = zoom * 1.0 / 2 # mm
teeth = 36 / 1 # number of teeth 36: for gear

# cnc settings
tool_diam = 1 # mm  - diameter of the cutting tool - NO ZOOM HERE!
stepover_factor = 0.80 # 1 is no overlap, 0.5 is 50% overlap
depth = hub_height - gear_base_height
depth_of_cut = 0.25  # mm - depth of cut per pass

# gcode settings
offset = zoom * 1.3 # mm
z_start = hub_height + 2 # mm   # lift for clearance


# variables to keep track of the cutter position
r1 = gear_radius_innner - offset # inner radius
r2 = gear_radius + offset # outer radius
start = [r1, 0]
prev = start

# define printer dimensions and center
width = 200
cx, cy = width / 2, width / 2

gcode = ['G21; mm units']
gcode << "G90; absolute positioning"
gcode << "G1 Z#{z_start} F1000" # move to z_start
gcode << "G1 X#{start[0] + cx} Y#{start[1] + cy} F1000" # move to start

rvg = RVG.new(width.mm, width.mm).viewbox(0, 0, 200, 200) do |canvas|
  # visualise the geometry
  canvas.background_fill = 'lightgray'
  canvas.line(0, 0, start[0] + cx, start[1] + cy)
  canvas.circle(hub_radius, cx, cy).styles(:stroke=>'blue', fill: 'none')
  canvas.circle(gear_radius, cx, cy).styles(:stroke=>'blue', fill: 'none')
  canvas.circle(gear_radius_innner, cx, cy).styles(:stroke=>'blue', fill: 'none')

  #set feed rate
  gcode << "G1 F60" # set feed rate to 60mm/min, thus 1mm/s

  # cut inner, then outer pocket
  cut_circular_pocket(canvas, zoom, gcode, cx, cy, hub_radius, gear_radius_innner, stepover_factor, tool_diam, depth, depth_of_cut)
  cut_circular_pocket(canvas, zoom, gcode, cx, cy, gear_radius, gear_radius + zoom*4, stepover_factor, tool_diam, depth, depth_of_cut) # 4mm extra outside

  canvas.g.translate(cx, cy) do |body|
    body.styles(:stroke=>'red', :stroke_width=>1)

    # make cuts across the circle to form the teeth
    num_cuts = teeth # + 1 is not needed
    angle = 360.0 / teeth # num_cuts
    num_cuts.times do |i|
      theta = i * angle * Math::PI / 180
      p1 = from_polar(r1, theta)
      p2 = from_polar(r2, theta)
      if i.even?
        first, second = p1, p2
      else
        first, second = p2, p1
      end
      body.line(*prev, *first) # move tangent to the circle
      body.line(*first, *second) # cut radially
      gcode << "G1 X#{(cx + first[0]).round(3)} Y#{(cy + first[1]).round(3)}"
      gcode << "G1 X#{(cx + second[0]).round(3)} Y#{cy + second[1].round(3)}"
      prev = second
      #puts *p1, *p2
    end
    # move z up
    gcode << "G1 Z#{z_start} F1000" # move to z_start
  end
end

rvg.draw.write('lines.png')

IO.write("cuts.gcode", gcode.join("\n"))
