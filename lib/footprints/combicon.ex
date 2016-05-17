defmodule Footprints.Combicon do
  alias Footprints.Components, as: Comps

  @library_name "COMBICON_Headers"
  @device_file_name "combicon_devices.yml"


  def create_mod(params, pincount, filename) do
      silktextheight    = params[:silktextheight]
      silktextwidth     = params[:silktextwidth]
      silktextthickness = params[:silktextthickness]
      silkoutlinewidth  = params[:silkoutlinewidth]
      courtyardmargin   = params[:courtyardmargin]
      pinpitch          = params[:pinpitch]
      drilldia          = params[:drilldia]

      bodyedgex         = 2.5
      bodyoffsetx       = 1.5
      bodyoffsety       = 1.3

      bodylen     = pinpitch*(pincount-1) + bodyedgex + bodyoffsetx  # extent in x
      bodywid     = 12 # extent in y

      # Bounding "courtyard" for the device
      crtydlength = bodylen + 2*courtyardmargin
      crtydwidth  = bodywid + 2*courtyardmargin
      courtyard = Comps.box(ll: {-crtydlength/2-bodyoffsetx/2,  crtydwidth/2-bodyoffsety},
                            ur: { crtydlength/2-bodyoffsetx/2, -crtydwidth/2-bodyoffsety},
                            layer: "F.CrtYd", width: silkoutlinewidth)

      # The grid of pads.  We'll call the common function from the PTHHeader
      # module for each pin location.
      pads = for pin <- 1..pincount, do:
               Footprints.PTHHeader.make_pad(params, pin, 1, pincount, 1)

      # Add the header outline.
      frontSilkBorder = [Comps.box(ll: {-bodylen/2-bodyoffsetx/2,  bodywid/2-bodyoffsety},
                                   ur: { bodylen/2-bodyoffsetx/2, -bodywid/2-bodyoffsety},
                                   layer: "F.SilkS", width: silkoutlinewidth),
                         Comps.line(start: {-bodylen/2-bodyoffsetx/2+bodyoffsetx, bodywid/2-bodyoffsety},
                                   end: {-bodylen/2-bodyoffsetx/2+bodyoffsetx,-bodywid/2-bodyoffsety},
                                   layer: "F.SilkS", width: silkoutlinewidth),
                         Comps.line(start: {-bodylen/2-bodyoffsetx/2+bodyoffsetx, bodyoffsety+1.5*drilldia},
                                    end: {bodylen/2-bodyoffsetx/2, bodyoffsety+1.5*drilldia},
                                    layer: "F.SilkS", width: silkoutlinewidth),
                         Comps.line(start: {-bodylen/2-bodyoffsetx/2+bodyoffsetx, -2*drilldia},
                                    end: {bodylen/2-bodyoffsetx/2, -2*drilldia},
                                    layer: "F.SilkS", width: silkoutlinewidth)]
      wireEntryMarks = for pin <- 1..pincount do
                         xc = -((pincount-1)/2*pinpitch) + (pin-1)*pinpitch
                         yc = bodyoffsety + drilldia/2
                         Comps.circle(center: {xc,yc}, radius: drilldia/2, layer: "F.SilkS", width: silkoutlinewidth)
                       end
      releaseMarks = for pin <- 1..pincount do
                       llx = -((pincount-1)/2*pinpitch) + (pin-1)*pinpitch - drilldia/2
                       lly = -2.5*drilldia
                       urx = llx + drilldia
                       ury = -bodywid/2-bodyoffsety + drilldia
                       Comps.box(ll: {llx,lly}, ur: {urx,ury}, layer: "F.SilkS", width: silkoutlinewidth)
                     end
      releaseArrows = for pin <- 1..pincount do
                        lx = -((pincount-1)/2*pinpitch) + (pin-1)*pinpitch
                        ly = bodyoffsety + drilldia/2 + 2.25*drilldia
                        ux = lx
                        uy = bodyoffsety + drilldia/2 + 1.5*drilldia
                        [Comps.line(start: {lx, ly}, end: {ux,uy}, layer: "Dwgs.User", width: silkoutlinewidth),
                         Comps.line(start: {ux-0.25, uy+0.25}, end: {ux,uy}, layer: "Dwgs.User", width: silkoutlinewidth),
                         Comps.line(start: {ux+0.25, uy+0.25}, end: {ux,uy}, layer: "Dwgs.User", width: silkoutlinewidth)]
                      end


      # Put all the module pieces together, create, and write the module
      features = List.flatten(pads) ++ courtyard ++ frontSilkBorder ++
                       wireEntryMarks ++ releaseMarks ++ releaseArrows

      refloc      = {-crtydlength/2-bodyoffsetx/2 - 0.75*silktextheight, 0, 90}
      valloc      = { crtydlength/2-bodyoffsetx/2 + 0.75*silktextheight, 0, 90}
      {:ok, file} = File.open filename, [:write]
      m = Comps.module(name: "Combicon_Header_#{pincount}",
                       valuelocation: valloc,
                       referencelocation: refloc,
                       textsize: {silktextheight,silktextwidth},
                       textwidth: silktextthickness,
                       descr: "#{pincount} Spring-Cage PCB Termination Blocks",
                       tags: ["PTH", "unshrouded", "header"],
                       isSMD: false,
                       features: features)
      IO.binwrite file, "#{m}"
      File.close file
    end


  def build(defaults, overrides, output_base_directory, config_base_directory) do
    output_directory = "#{output_base_directory}/#{@library_name}.pretty"
    File.mkdir(output_directory)

    # Note that for the headers we'll just define the pin layouts (counts)
    # programatically.  We won't use the device sections of the config file
    # to define the number of pins or rows.

    #
    # 0.05" (1.27 mm) headers
    #

    # Override default parameters for this library (set of modules) and add
    # device specific values.  The override based on command line parameters
    # (passed in via `overrides` variable)
    temp = YamlElixir.read_from_file("#{config_base_directory}/#{@device_file_name}")
    p = Enum.map(temp["defaults"], fn({k,v})-> Map.put(%{}, String.to_atom(k), v) end)
        |> Enum.reduce(fn(data, acc)-> Map.merge(data,acc) end)
    p2 = Map.merge defaults, p
    params = Map.merge p2, overrides

    pinpitch = params[:pinpitch]
    devices = for pincount <- 2..24, do: {pincount}
    Enum.map(devices, fn {pincount} ->
                  filename = "#{output_directory}/COMBICON_HDR#{round(pinpitch*100.0)}P#{pincount}.kicad_mod"
                  create_mod(params, pincount, filename)
                end)
    :ok
  end

end