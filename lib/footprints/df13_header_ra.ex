defmodule Footprints.DF13HeaderRA do
  alias Footprints.Components, as: Comps


  def create_mod(params, pincount, _rowcount, filename) do
      silktextheight    = params[:silktextheight]
      silktextwidth     = params[:silktextwidth]
      silktextthickness = params[:silktextthickness]
      silkoutlinewidth  = params[:silkoutlinewidth]
      courtyardmargin   = params[:courtyardmargin]
      pinpitch          = params[:pinpitch]
      padheight         = params[:padheight]
      maskmargin        = params[:soldermaskmargin]

      # All pins aligned at y=0
      #  lower face at y=0.90
      #  upper face at y=-4.50
      lower = 0.90
      upper = -4.50

      bodylen  = pinpitch*(pincount-1) + 2.9

      # Bounding "courtyard" for the device
      crtydlength = (bodylen + padheight) + courtyardmargin
      courtyard = Comps.box({-crtydlength/2, lower+courtyardmargin},
                            { crtydlength/2, upper-courtyardmargin},
                            "F.CrtYd", silkoutlinewidth)

      # The grid of pads.  We'll call the common function from the PTHHeader
      # module for each pin location.
      pads = for pin <- 1..pincount, do:
                if pin == 1, do:
                  Footprints.PTHHeaderSupport.make_pad(params, pin, 1, pincount, 1, "rect", maskmargin),
                else:
                  Footprints.PTHHeaderSupport.make_pad(params, pin, 1, pincount, 1, "oval", maskmargin)


      # Outline
      y1 = -0.85
      outline = [Comps.line({-bodylen/2,lower}, {bodylen/2,lower}, "F.SilkS", silkoutlinewidth),
                 Comps.line({-bodylen/2,upper}, {bodylen/2,upper}, "F.SilkS", silkoutlinewidth),
                 Comps.line({-bodylen/2,upper}, {-bodylen/2,lower}, "F.SilkS", silkoutlinewidth),
                 Comps.line({bodylen/2,upper}, {bodylen/2,lower}, "F.SilkS", silkoutlinewidth),
                 Comps.line({-bodylen/2,y1}, {bodylen/2,y1}, "F.SilkS", silkoutlinewidth)]


      # Put all the module pieces together, create, and write the module
      features = List.flatten(pads) ++ courtyard ++ outline

      refloc = if pincount > 3, do: {0, (lower+upper)/2},
               else: {-crtydlength/2 - 0.75*silktextheight, (lower+upper)/2}
      valloc = if pincount > 3, do: {0, (lower+upper)/2-1.5*silktextheight},
               else: { crtydlength/2 + 0.75*silktextheight, (lower+upper)/2}

      descr = "Hirose DF13 right angle through hole connector";
      tags = ["PTH", "header", "shrouded"]
      name = "DF13-#{pincount}P-1.25DS"
      textsize = {silktextheight,silktextwidth}
      m = Comps.module(name, descr, features, refloc, valloc, textsize, silktextthickness, tags)
      {:ok, file} = File.open filename, [:write]
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
    devices = for pincount <- [2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,40], do: pincount
    Enum.map(devices, fn pincount ->
                  filename = "#{output_directory}/DF13-#{pincount}P-#{round(pinpitch*100.0)}DS.kicad_mod"
                  create_mod(params, pincount, 1, filename)
                end)
    :ok
  end

end
