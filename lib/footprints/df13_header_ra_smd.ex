defmodule Footprints.DF13HeaderRASMD do
  alias Footprints.Components, as: Comps


  def create_mod(params, pincount, _rowcount, filename) do
      silktextheight    = params[:silktextheight]
      silktextwidth     = params[:silktextwidth]
      silktextthickness = params[:silktextthickness]
      silkoutlinewidth  = params[:silkoutlinewidth]
      courtyardmargin   = params[:courtyardmargin]
      pinpitch          = params[:pinpitch]
      padheight         = params[:padheight]
      pindia            = params[:pindia]
      padwidth          = params[:padwidth]
      supppadheight     = params[:supppadheight]
      supppadwidth      = params[:supppadwidth]
      maskmargin        = params[:soldermaskmargin]
      pastemargin       = params[:solderpastemarginratio]

      # All pins aligned at y=0
      #  lower face at y=1.21
      #  upper face at y=2.19
      lower = -0.4
      upper = -5

      bodylen  = pinpitch*(pincount-1) + 2.9

      # Bounding "courtyard" for the device
      crtydlength = bodylen + 2*(supppadwidth + courtyardmargin)
      courtyard = Comps.box(ll: {-crtydlength/2, padheight/2+courtyardmargin},
                            ur: { crtydlength/2, upper-courtyardmargin},
                            layer: "F.CrtYd", width: silkoutlinewidth)

      # The grid of pads.  We'll call the common function from the PTHHeader
      # module for each pin location.
      pads = for pin <- 1..pincount, do:
        Footprints.SMDHeaderSupport.make_pad(params, pin, 1, pincount, 1, "rect", maskmargin, pastemargin)

      pinYc = lower - 2.015
      pinmarks = for pin <- 1..pincount, do:
        Comps.box(ll: {-((pincount-1)/2*pinpitch) + (pin-1)*pinpitch - pindia/2, -padheight/2-silkoutlinewidth},
                  ur: {-((pincount-1)/2*pinpitch) + (pin-1)*pinpitch + pindia/2, -4},
                  layer: "F.SilkS", width: silkoutlinewidth)

      sx = (bodylen + padheight)/2
      sy = -3.3
      supportPads = [Comps.padSMD(name: "S", shape: "rect", at: {-sx,sy},
                                  size: {supppadwidth,supppadheight},
                                  pastemargin: pastemargin,
                                  maskmargin: maskmargin),
                     Comps.padSMD(name: "S", shape: "rect", at: {sx,sy},
                                  size: {supppadwidth,supppadheight},
                                  pastemargin: pastemargin,
                                  maskmargin: maskmargin)]

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
      outline = [Comps.line(start: {-bodylen/2,lower}, end: {bodylen/2,lower}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {-bodylen/2,upper}, end: {bodylen/2,upper}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {-bodylen/2,upper}, end: {-bodylen/2,lower}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {bodylen/2,upper}, end: {bodylen/2,lower}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {left, top}, end: {x1,top}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {x2, top}, end: {x3,top}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {x4, top}, end: {right,top}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {left, top}, end: {left,y1}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {left, y2}, end: {left,bottom},layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {right, top}, end: {right,y1}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {right, y2}, end: {right,bottom}, layer: "F.SilkS", width: silkoutlinewidth),
                 Comps.line(start: {left, bottom}, end: {right,bottom}, layer: "F.SilkS", width: silkoutlinewidth)]



      # Put all the module pieces together, create, and write the module
      features = List.flatten(pads) ++ courtyard ++ outline ++ supportPads ++ pinmarks

      refloc = {-crtydlength/2 - 0.75*silktextheight, (lower+upper)/2, 90}
      valloc = { crtydlength/2 + 0.75*silktextheight, (lower+upper)/2, 90}
      descr = "Hirose DF13 surface mount right angle connector";
      tags = ["SMD", "header", "shrouded", "right angle"]
      name = "DF13-RA-#{pincount}P-1.25DSA"
      {:ok, file} = File.open filename, [:write]
      m = Comps.module(name: name,
                       valuelocation: valloc,
                       referencelocation: refloc,
                       textsize: {silktextheight,silktextwidth},
                       textwidth: silktextthickness,
                       descr: descr,
                       tags: tags,
                       isSMD: false,
                       features: features)
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
                  filename = "#{output_directory}/DF13-RA-#{pincount}P-#{round(pinpitch*100.0)}DSA.kicad_mod"
                  create_mod(params, pincount, 1, filename)
                end)
    :ok
  end

end