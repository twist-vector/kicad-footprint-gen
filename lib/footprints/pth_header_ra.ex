defmodule Footprints.PTHHeaderRA do
  alias Footprints.Components, as: Comps

  def create_mod(params, pincount, rowcount, filename) do
    silktextheight    = params[:silktextheight]
    silktextwidth     = params[:silktextwidth]
    silktextthickness = params[:silktextthickness]
    silkoutlinewidth  = params[:silkoutlinewidth]
    courtyardmargin   = params[:courtyardmargin]
    pinpitch          = params[:pinpitch]
    rowpitch          = params[:rowpitch]
    padwidth          = params[:padwidth]
    padheight         = params[:padheight]
    pindia            = params[:pindia]
    pinlength         = params[:pinlength]
    bodyoffset        = params[:bodyoffset]
    bodythick         = params[:bodythick]
    maskmargin        = params[:soldermaskmargin]

    bodylen     = pinpitch*(pincount-1) + padwidth  # extent in x
    bodywid     = rowpitch*(rowcount-1) + padheight # extent in y

    crtydlength = bodylen/2 + padwidth/2 + courtyardmargin


    # Bounding "courtyard" for the device
    ll = {-crtydlength,
           pinpitch*(rowcount-1)/2 + padheight + courtyardmargin}
    ur = { crtydlength,
          -pinpitch*(rowcount-1)/2 - bodyoffset - bodythick - pinlength - courtyardmargin/2}
    courtyard = Comps.box(ll, ur, "F.CrtYd", silkoutlinewidth)

    # The silkscreen outline...

    # Border of the body
    ll = {-pinpitch*(pincount-1)/2-pinpitch/2,
          -pinpitch*(rowcount-1)/2 - bodyoffset}
    ur = { pinpitch*(pincount-1)/2+pinpitch/2,
          -pinpitch*(rowcount-1)/2 - bodyoffset - bodythick}
    frontSilkBorder = Comps.box(ll, ur, "F.SilkS", silkoutlinewidth)

    # outline of the pins
    frontSilkPin = for pin <- 1..pincount do
          ll = {-pinpitch*(pincount-1)/2 + (pin-1)*pinpitch - pindia/2,
                -pinpitch*(rowcount-1)/2 - bodyoffset - bodythick}
          ur = {-pinpitch*(pincount-1)/2 + (pin-1)*pinpitch + pindia/2,
                -pinpitch*(rowcount-1)/2 - bodyoffset - bodythick - pinlength}
           Comps.box(ll, ur, "F.SilkS", silkoutlinewidth)
      end


     # The grid of pads.  We'll call the common function from the PTHHeader
     # module for each pin location.
     pads = for row <- 1..rowcount, do:
              for pin <- 1..pincount, do:
                Footprints.PTHHeaderSupport.make_pad(params, pin, row, pincount, rowcount, "oval", maskmargin)

     # Pin 1 marker (circle)
     xcc = bodylen/2 + padwidth/4
     ycc = bodywid/2 + padheight/4
     c = Comps.circle({-xcc,ycc}, 0.1, "F.SilkS", silkoutlinewidth)

    # Put all the module pieces together, create, and write the module
    features = List.flatten(pads) ++ frontSilkBorder ++
               List.flatten(frontSilkPin)  ++ courtyard ++ [c]

    {:ok, file} = File.open filename, [:write]
    refloc      = {-crtydlength - 0.75 * silktextheight, 0}
    valloc      = { crtydlength + 0.75 * silktextheight, 0}
    m = Comps.module("Header_#{pincount}x#{rowcount}_RA",
                     "#{pincount}x#{rowcount} 0.10in (2.54 mm) spacing right angle unshrouded header",
                     features,
                     refloc,
                     valloc,
                     {silktextheight,silktextwidth},
                     silktextthickness)
    IO.binwrite file, "#{m}"
    File.close file
  end


  def build(library_name, device_file_name, defaults, overrides, output_base_directory, config_base_directory) do
    output_directory = "#{output_base_directory}/#{library_name}.pretty"
    File.mkdir(output_directory)

    # Override default parameters for this library (set of modules) and add
    # device specific values.  The override based on command line parameters
    # (passed in via `overrides` variable)
    params = FootprintSupport.make_params("#{config_base_directory}/#{device_file_name}", defaults, overrides)

    # Note that for the headers we'll just define the pin layouts (counts)
    # programatically.  We won't use the device sections of the config file
    # to define the number of pins or rows.
    pinpitch = params[:pinpitch]
    devices = for pincount <- 1..40, rowcount <- 1..3, pincount>=rowcount, do: {pincount,rowcount}
    Enum.map(devices, fn {pincount,rowcount} ->
                  filename = "#{output_directory}/HDR_RA#{round(pinpitch*100.0)}P#{pincount}x#{rowcount}.kicad_mod"
                  create_mod(params, pincount, rowcount, filename)
                end)

    :ok
  end

end
