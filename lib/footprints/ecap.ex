defmodule Footprints.ECap do
  alias Footprints.Components, as: Comps

  def create_mod(params, name, descr, tags, filename) do
    #
    # Device oriented left-to-right:  Body length is then in the KiCad x
    # direction, body width is in the y direction.
    #
    silktextheight    = params[:silktextheight]
    silktextwidth     = params[:silktextwidth]
    silktextthickness = params[:silktextthickness]
    silkoutlinewidth  = params[:silkoutlinewidth]
    courtoutlinewidth = params[:courtoutlinewidth]
    courtyardmargin   = params[:courtyardmargin]
    placetickmargin   = params[:placetickmargin]
    toefillet         = params[:toefillet]
    heelfillet        = params[:heelfillet]
    sidefillet        = params[:sidefillet]
    pinlentol         = params[:pinlentol] # pin length is in the x direction
    pinwidthmin       = params[:pinwidthmin]
    pinwidthmax       = params[:pinwidthmax]
    pinsep            = params[:pinsep]
    placetol          = params[:placetol]
    fabtol            = params[:fabtol]
    bodylen           = params[:bodylen]
    bodywid           = params[:bodywid]
    cyldiam           = params[:cyldiam]
    legland           = params[:legland]
    pastemargin       = params[:solderpastemarginratio]
    maskmargin        = params[:soldermaskmargin]
    shape             = params[:padshape]


    totaltol  = :math.sqrt(:math.pow(pinlentol, 2)+:math.pow(fabtol, 2)+:math.pow(placetol, 2))

    padSizeX = legland + heelfillet + toefillet + totaltol
    padSizeY = (pinwidthmax+pinwidthmin)/2 + 2*sidefillet + totaltol

    padCenterX = pinsep/2 + padSizeX/2 - heelfillet
    padCenterY = 0;

    crtydSizeX = 2*(max(padCenterX+padSizeX/2, bodylen/2) + courtyardmargin)
    crtydSizeY = 2*(max(padCenterY+padSizeY/2, bodywid/2) + courtyardmargin)

    pads = [Comps.pad(:smd, "1", shape, {-padCenterX, padCenterY}, {padSizeX, padSizeY}, pastemargin, maskmargin),
            Comps.pad(:smd, "2", shape, { padCenterX, padCenterY}, {padSizeX, padSizeY}, pastemargin, maskmargin)]

    x1 =   bodylen/2
    x2 = - bodylen/2 + bodylen/5
    x3 = - bodylen/2
    y1 =   bodywid/2
    y2 = y1 - bodywid/5
    xn = x1/2
    yn = :math.sqrt( (cyldiam/2)*(cyldiam/2) - xn*xn )

    yt = padSizeY/2 + placetickmargin
    xt = :math.sqrt( (cyldiam/2)*(cyldiam/2) - yt*yt )
    theta = :math.asin(yt/cyldiam)
    ang = 180 - 4*(theta*180/:math.pi)

    silk = [Comps.line({x1, y1}, {x2, y1}, "F.SilkS", silkoutlinewidth),
            Comps.line({x2, y1}, {x3, y2}, "F.SilkS", silkoutlinewidth),
            Comps.line({x3, y2}, {x3, yt}, "F.SilkS", silkoutlinewidth),
            Comps.line({x3,-yt}, {x3,-y2}, "F.SilkS", silkoutlinewidth),
            Comps.line({x3,-y2}, {x2,-y1}, "F.SilkS", silkoutlinewidth),
            Comps.line({x2,-y1}, {x1,-y1}, "F.SilkS", silkoutlinewidth),
            Comps.line({x1,-y1}, {x1,-yt}, "F.SilkS", silkoutlinewidth),
            Comps.line({x1, yt}, {x1, y1}, "F.SilkS", silkoutlinewidth),
            Comps.circle({0,0}, cyldiam/2, "Eco1.User", silkoutlinewidth),
            Comps.arc(start: {0,0}, end: {xt,yt}, angle: ang, layer: "F.SilkS", width: silkoutlinewidth),
            Comps.arc(start: {0,0}, end: {xt,-yt}, angle: -ang, layer: "F.SilkS", width: silkoutlinewidth)]


    courtyard = Comps.box({-crtydSizeX/2,crtydSizeY/2},
                          {crtydSizeX/2,-crtydSizeY/2},
                          "F.CrtYd", courtoutlinewidth)

    outline = [Comps.line({x1, y1}, {x2, y1}, "Eco1.User", silkoutlinewidth),
               Comps.line({x2, y1}, {x3, y2}, "Eco1.User", silkoutlinewidth),
               Comps.line({x3, y2}, {x3, -y2}, "Eco1.User", silkoutlinewidth),
               Comps.line({x3,-y2}, {x2,-y1}, "Eco1.User", silkoutlinewidth),
               Comps.line({x2,-y1}, {x1,-y1}, "Eco1.User", silkoutlinewidth),
               Comps.line({x1,-y1}, {x1,y1}, "Eco1.User", silkoutlinewidth),
               Comps.line({xn,-yn}, {xn,yn}, "Eco1.User", silkoutlinewidth),
               Comps.circle({0,0}, cyldiam/2, "Eco1.User", silkoutlinewidth)]


    features = pads ++ [Enum.join(courtyard, "\n  ")] ++
        [Enum.join(outline, "\n  ")] ++ silk

    refloc   = {-crtydSizeX/2 - 0.75*silktextheight, 0}
    valloc   = { crtydSizeX/2 + 0.75*silktextheight, 0}
    textsize = {silktextheight,silktextwidth}

    m = Comps.module(name, descr, features, refloc, valloc, textsize, silktextthickness, tags)

    {:ok, file} = File.open filename, [:write]
    IO.binwrite file, "#{m}"
    File.close file
  end


  def build(library_name, device_file_name, basedefaults, overrides, output_base_directory, config_base_directory) do
    output_directory = "#{output_base_directory}/#{library_name}.pretty"
    File.mkdir(output_directory)

    # Override default parameters for this library (set of modules) and add
    # device specific values.  The override based on command line parameters
    # (passed in via `overrides` variable)
    temp = YamlElixir.read_from_file("#{config_base_directory}/#{device_file_name}")
    defaults = FootprintSupport.make_params("#{config_base_directory}/#{device_file_name}", basedefaults, overrides)

    for dev_name <- Map.keys(temp) do
      if dev_name != "defaults" do

        # temp[dev_name] is a list of Dicts.  Each element is the parameters list
        # to be used for the device
        Enum.map(temp[dev_name], fn d ->
          p = Enum.map(d, fn {k,v} -> Map.put(%{}, String.to_atom(k), v) end)
              |> Enum.reduce(fn(data, acc)-> Map.merge(data,acc) end)
          params = Map.merge(defaults, p)
                   |> Map.merge(overrides)

          bl = params[:bodylen]*10
          bw = params[:bodywid]*10

          metriccode = List.flatten(:io_lib.format("~w~w", [round(bl),round(bw)]))
          imperialcode = if params[:inchcode] == nil do
                            bli = bl * 0.393701
                            bwi = bw * 0.393701
                            List.flatten(:io_lib.format("~w~w", [round(bli),round(bwi)]))
                         else
                            params[:inchcode]
                         end

          filename = "#{output_directory}/#{dev_name}-#{metriccode}-#{imperialcode}.kicad_mod"
          tags = ["SMD", "chip", metriccode]
          create_mod(params, "#{metriccode}_chip_dev",
                     "#{metriccode} (metric) chip device",
                     tags, filename)
        end)
      end
    end

    :ok
  end

end
