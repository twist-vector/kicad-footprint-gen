defmodule Footprints.DF13HeaderSMD do
  alias Footprints.Components, as: Comps


  def create_mod(params, pincount, _rowcount, filename) do
      silktextheight    = params[:silktextheight]
      silktextwidth     = params[:silktextwidth]
      silktextthickness = params[:silktextthickness]
      silkoutlinewidth  = params[:silkoutlinewidth]
      courtyardmargin   = params[:courtyardmargin]
      pinpitch          = params[:pinpitch]
      padheight         = params[:padheight]
      supppadheight     = params[:supppadheight]
      supppadwidth      = params[:supppadwidth]
      maskmargin        = params[:soldermaskmargin]
      pastemargin       = params[:solderpastemarginratio]
      shape             = params[:padshape]


      # All pins aligned at y=0
      #  lower face at y=1.21
      #  upper face at y=2.19
      lower = -0.4
      upper = -3.8

      bodylen  = pinpitch*(pincount-1) + 2.9

      # Bounding "courtyard" for the device
      crtydlength = bodylen + 2*(supppadwidth + courtyardmargin)
      courtyard = Comps.box({-crtydlength/2, padheight/2+courtyardmargin},
                            { crtydlength/2, upper-courtyardmargin},
                            "F.CrtYd", silkoutlinewidth)

      # The grid of pads.  We'll call the common function from the PTHHeader
      # module for each pin location.
      pads = for pin <- 1..pincount, do:
        Footprints.SMDHeaderSupport.make_pad(params, pin, 1, pincount, 1, shape, maskmargin, pastemargin)

      pinYc = lower - 2.015
      pinmarks = for pin <- 1..pincount, do:
        Comps.circle({-((pincount-1)/2*pinpitch) + (pin-1)*pinpitch, pinYc}, 0.3, "F.SilkS", silkoutlinewidth)

      sx = (bodylen + padheight)/2
      sy = -2.1
      supportPads = [Comps.pad(:smd, "S", shape, {-sx,sy}, {supppadwidth,supppadheight}, pastemargin, maskmargin),
                     Comps.pad(:smd, "S", shape, { sx,sy}, {supppadwidth,supppadheight}, pastemargin, maskmargin)]

      # Outline
      left = -bodylen/2 + 0.9*silkoutlinewidth
      right = -left
      top = upper + 0.95*silkoutlinewidth
      bottom = lower - 0.9*silkoutlinewidth
      x1 = left + 0.5
      gap = 1.0
      x2 = x1 + gap
      x3 = right - 0.5 - gap
      x4 = right - 0.5
      y1 = top + 0.5
      y2 = y1 + gap
      outline = [Comps.line({-bodylen/2,lower}, {bodylen/2,lower}, "F.SilkS", silkoutlinewidth),
                 Comps.line({-bodylen/2,upper}, {bodylen/2,upper}, "F.SilkS", silkoutlinewidth),
                 Comps.line({-bodylen/2,upper}, {-bodylen/2,lower}, "F.SilkS", silkoutlinewidth),
                 Comps.line({bodylen/2,upper}, {bodylen/2,lower}, "F.SilkS", silkoutlinewidth),
                 Comps.line({left, top}, {x1,top}, "F.SilkS", silkoutlinewidth),
                 Comps.line({x2, top}, {x3,top}, "F.SilkS", silkoutlinewidth),
                 Comps.line({x4, top}, {right,top}, "F.SilkS", silkoutlinewidth),
                 Comps.line({left, top}, {left,y1}, "F.SilkS", silkoutlinewidth),
                 Comps.line({left, y2}, {left,bottom},"F.SilkS", silkoutlinewidth),
                 Comps.line({right, top}, {right,y1}, "F.SilkS", silkoutlinewidth),
                 Comps.line({right, y2}, {right,bottom}, "F.SilkS", silkoutlinewidth),
                 Comps.line({left, bottom}, {right,bottom}, "F.SilkS", silkoutlinewidth)]



      # Put all the module pieces together, create, and write the module
      features = List.flatten(pads) ++ courtyard ++ outline ++ supportPads ++ pinmarks

      refloc   = {-crtydlength/2 - 0.75*silktextheight, (lower+upper)/2}
      valloc   = { crtydlength/2 + 0.75*silktextheight, (lower+upper)/2}
      descr    = "Hirose DF13 surface mount connector";
      tags     = ["SMD", "header", "shrouded"]
      name     = "DF13-#{pincount}P-1.25DSA"
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
                  filename = "#{output_directory}/DF13-#{pincount}P-#{round(pinpitch*100.0)}DSA.kicad_mod"
                  create_mod(params, pincount, 1, filename)
                end)
    :ok
  end

end
