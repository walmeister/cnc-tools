require 'rvg/rvg'
include Magick

# taken from tut https://rmagick.github.io/rvgtut.html

# The idea is to manually generate gcode to cut a gear for a quadcopter replacement
# Visualize the cutter movements and generate the gcode to cut it


# PROMBLEMS
# - Do the gcode and worry about visualizing later

# TODO:
# Add z positions to the gcode, annd number of cuts
# - Add a way to visualize the cutter movements from the gcode
# - Add operations to mill the hub and crown, then the teeth

def from_polar(r, theta)
  [r * Math.cos(theta), r * Math.sin(theta)]
end

RVG::dpi = 72

# define the gear
radius = 10 * 15/2.0 # mm approximately !!! change 1 to 10 to view zoomed in
crown_height = 2.5 # mm
hub_height = 6.25 # mm
teeth = 36 / 2

# gcode settings
offset = 13 # mm
z_start = hub_height + 2 # mm   # lift for clearance


# variables to keep track of the cutter position
r1 = radius - offset # inner radius
r2 = radius + offset # outer radius
start = [r1, 0]
prev = start

width = 200
cx, cy = width / 2, width / 2

gcode = ['G21; mm units']
gcode << "G1 Z#{z_start} F1000" # move to z_start
gcode << "G1 X#{start[0] + cx} Y#{start[1] + cy} F1000" # move to start

zoom_factor = 1.0 # Increase this to zoom in more
#rvg = RVG.new(width.mm, width.mm).viewbox(cx - (2*radius), cy - (2*radius), 4*radius, 4*radius) do |canvas|
rvg = RVG.new(width.mm, width.mm).viewbox(0, 0, 200, 200) do |canvas|
  canvas.background_fill = 'lightgray'
  canvas.line(0, 0, start[0] + cx, start[1] + cy)
  canvas.circle(radius, cx, cy).styles(:stroke=>'blue', fill: 'none') # radius, x, y

  #set feed rate
  gcode << "G1 F60" # set feed rate to 60mm/min, thus 1mm/s

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
  end
end

rvg.draw.write('lines.png')

IO.write("cuts.gcode", gcode.join("\n"))
