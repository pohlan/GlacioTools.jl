SGI_IDS = Dict( "Rhone"       => "B43/03",
                "Aletsch"     => "B36/26",
                "PlaineMorte" => "A55f/03",
                "Morteratsch" => "E22/03",
                "Arolla"      => "B73/14",
                "ArollaHaut"  => "B73/12")

"""
    fetch_glacier(name; destination_dir)

# Input
- name -- must be one of the following: "Rhone", "Aletsch", "PlaineMorte", "Morteratsch", "Arolla"
- destination_dir -- path of the directory to store the download

# Output
- struct of type `GlacioTools.DataElevation`` with fields x, y, z_bed, z_surf and rotation matrix R
"""
function fetch_glacier(name::String; destination_dir::String)
    # download
    get_all_data("https://www.dropbox.com/s/3htehzra9bv6j75/alps_sgi.zip?dl=0",destination_dir)
    # select the relevant elevation data
    geom_select(SGI_IDS[name], name, destination_dir)
    extract_geodata(Float64, name, destination_dir)
    return load_elevation(destination_dir * "alps/data_" * name * ".h5")
end

"""
    geom_select(SGI_ID::String, name::String; padding::Int=10, do_vis=true, do_save=true)

Select ice thickness, surface and bedrock elevation data for a given Alpine glacier based on SGI ID.

# Input
- `SGI_ID::String`: desired data type for elevation data
- `name::String`: input data file

# Optional keyword args
- `padding::Int=10`: padding around the glacier geometry
- `do_vis=true`: do visualisation
- `do_save=true`: save output to HDF5
"""
@views function geom_select(SGI_ID::String, name::String, destination_dir; padding::Int=10, do_save=true)
    if isfile(destination_dir * "alps/IceThick_cr0_$(name).tif") && isfile(destination_dir * "alps/SurfElev_cr_$(name).tif") && isfile(destination_dir * "alps/BedElev_cr_$(name).tif")
        return
    end

    # find glacier ID
    df  = DataFrame(DBFTables.Table(destination_dir * "alps_sgi/swissTLM3D_TLM_GLAMOS.dbf"))
    ID  = df[in([SGI_ID]).(df.SGI),:TLM_BODENB] # and not :UUID field!

    # read in global data
    print("Reading in global data... ")
    IceThick = read(Raster(destination_dir * "alps_sgi/IceThickness.tif"))
    SurfElev = read(Raster(destination_dir * "alps_sgi/SwissALTI3D_r2019.tif"))
    println("done.")

    count = 0
    IceThick_stack = []
    for id in ID
        count+=1
        # retrieve shape
        dftable = DataFrame(Shapefile.Table(destination_dir * "alps_sgi/swissTLM3D_TLM_BODENBEDECKUNG_ost.shp"))
        if sum(in([id]).(dftable.UUID))==0
            dftable = DataFrame(Shapefile.Table(destination_dir * "alps_sgi/swissTLM3D_TLM_BODENBEDECKUNG_west.shp"))
        end
        shape = dftable[in([id]).(dftable.UUID),:geometry]
        # find ice thickness for polygon of interest (glacier), crop and add padding, using global data
        IceThick_stack .= push!(IceThick_stack, mask_trim(IceThick, shape, padding))
    end

    IceThick_cr = mosaic(first, IceThick_stack)

    # crop surface elevation to ice thckness data
    SurfElev_cr = Rasters.crop(SurfElev; to=IceThick_cr)

    # compute bedrock elevation
    IceThick_cr0 = replace_missing(IceThick_cr, 0.0)
    BedElev_cr = SurfElev_cr .- IceThick_cr0

    print("Saving to file... ")
    # save
    if do_save
        if isdir(destination_dir * "alps")==false mkdir(destination_dir * "alps") end
        write(destination_dir * "alps/IceThick_cr0_$(name).tif", IceThick_cr0)
        write(destination_dir * "alps/SurfElev_cr_$(name).tif" , SurfElev_cr )
        write(destination_dir * "alps/BedElev_cr_$(name).tif"  , BedElev_cr  )
    end
    println("done.")

    return IceThick_cr0, SurfElev_cr, BedElev_cr
end

"""
    extract_geodata(type::DataType, dat_name::String)

Extract geadata and return bedrock and surface elevation maps, spatial coords and bounding-box rotation matrix.

# Inputs
- `type::DataType`: desired data type for elevation data
- `dat_name::String`: name of the glacier
"""
@views function extract_geodata(type::DataType, dat_name::String, destination_dir)
    if isfile(destination_dir * "alps/data_$(dat_name).h5")
        return
    end
    println("Starting geodata extraction ...")
    println("- load the data")
    file1     = (destination_dir * "alps/IceThick_cr0_$(dat_name).tif")
    file2     = (destination_dir * "alps/BedElev_cr_$(dat_name).tif"  )
    z_thick   = reverse(GeoArrays.read(file1)[:,:,1], dims=2)
    z_bed     = reverse(GeoArrays.read(file2)[:,:,1], dims=2)
    coords    = reverse(GeoArrays.coords(GeoArrays.read(file2)), dims=2)
    (x,y)     = (getindex.(coords,1), getindex.(coords,2))
    xmin,xmax = extrema(x)
    ymin,ymax = extrema(y)
    # center data in x,y plane
    x       .-= 0.5*(xmin + xmax)
    y       .-= 0.5*(ymin + ymax)
    # TODO: a step here could be rotation of the (x,y) plane using bounding box (rotating calipers)
    # define and apply masks
    mask                       = ones(type, size(z_thick))
    mask[ismissing.(z_thick)] .= 0
    z_thick[mask.==0]         .= 0
    z_thick                    = convert(Matrix{type}, z_thick)
    z_bed[ismissing.(z_bed)]  .= mean(my_filter(z_bed,mask))
    z_bed                      = convert(Matrix{type}, z_bed)
    # ground data in z axis
    z_bed                    .-= minimum(z_bed)
    # ice surface elevation and average between bed and ice
    z_surf                     = z_bed .+ z_thick
    z_avg                      = z_bed .+ convert(type,0.5).*z_thick
    println("- perform least square fit")
    αx, αy = lsq_fit(my_filter(x,mask),my_filter(y,mask),my_filter(z_avg,mask))
    # normal vector to the least-squares plane
    # rotation axis - cross product of normal vector and z-axis
    nv = [-αx  ,-αy   ,1.0]; nv ./= norm(nv)
    ax = [nv[2],-nv[1],0.0]; ax ./= norm(ax)
    # rotation matrix from rotation axis and angle
    R  = axis_angle_rotation_matrix(ax,acos(nv[3]))
    println("- save data to $destination_dir alps/data_$(dat_name).h5")
    h5open(destination_dir * "alps/data_$(dat_name).h5", "w") do fid
        create_group(fid, "glacier")
        fid["glacier/x",compress=3]      = x
        fid["glacier/y",compress=3]      = y
        fid["glacier/z_bed",compress=3]  = z_bed
        fid["glacier/z_surf",compress=3] = z_surf
        fid["glacier/R",compress=3]      = R
    end
    println("done.")
    return
end