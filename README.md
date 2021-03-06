# GlacioTools.jl

A package to assist in downloading and reading data, particularly glaciology relevant data from Antarctica and a few Alpine glaciers.

## General download
The general downloading routine `get_all_data()` (from [FourDAntarcticaSubglacialRouting.jl](https://github.com/mauro3/FourDAntarcticaSubglacialRouting.jl)) is flexible in its use:
```
get_all_data(myfile, destination_dir)
get_all_data(myfolder, destination_dir)
get_all_data(myurl, destination_dir)
get_all_data(mydictionary, destination_dir)
```
The file is saved to the folder `destination_dir`. If the input is a file or folder path, the file is simply copied. The input can also be a dictionary, e.g.:
```
datas = Dict(:example1 => "https://ex1.mat",
             :example2 => "https://ex2.zip")
```

### Password protected download
If the download requires a password, as e.g. for the [Antarctica bedmachine](https://urs.earthdata.nasa.gov/oauth/authorize?client_id=_JLuwMHxb2xX6NwYTb4dRA&response_type=code&redirect_uri=https%3A%2F%2Fn5eil01u.ecs.nsidc.org%2FOPS%2Fredirect&state=aHR0cDovL241ZWlsMDF1LmVjcy5uc2lkYy5vcmcvTUVBU1VSRVMvTlNJREMtMDc1Ni4wMDIvMTk3MC4wMS4wMS9CZWRNYWNoaW5lQW50YXJjdGljYV8yMDIwLTA3LTE1X3YwMi5uYw), the automatic download requires a `~/.netrc` file. In case of the bedmachine this file should look like the following
```
machine urs.earthdata.nasa.gov
login myusername
password 1234567
```
where `myusername` and `1234567` should be replaced by username and password, respectively. Note that no sensitive logins should be stored in such a way.

## Alpine glaciers
Download and read in the bed and surface topography of a selection of alpine glaciers (with routines from [FastIce.jl/GeoData](https://github.com/PTsolvers/FastIce.jl/tree/main/GeoData)).
```
SGI_ID = "B43/03"
destination_dir = "../mydata/"
data = fetch_glacier("Rhone", SGI_ID; destination_dir)
```
where `data` is a struct with entries `x`,`y`,`z_bed`,`z_surf` and `R` (rotation matrix). The `SGI_ID` number identifies the glacier in the dataset and can be found [here](https://www.research-collection.ethz.ch/bitstream/handle/20.500.11850/434697/00_TablesIllustrations(updatedversion).pdf?sequence=39&isAllowed=y). This is an example dictionary containing the `SGI_ID`s for six selected glaciers:
```
SGI_IDS = Dict( "Rhone"       => "B43/03",
                "Aletsch"     => "B36/26",
                "PlaineMorte" => "A55f/03",
                "Morteratsch" => "E22/03",
                "Arolla"      => "B73/14",
                "ArollaHaut"  => "B73/12")
```
The data is downloaded from:
- [Swisstopo swissTLM3D](https://www.swisstopo.admin.ch/en/geodata/landscape/tlm3d.html#download)
- [Grab 2020, Swiss Glacier Thickness ??? Release 2020 (ETH Research Collection)](https://www.research-collection.ethz.ch/handle/20.500.11850/434697) (`04_IceThickness_SwissAlps.zip` and `08_SurfaceElevation_SwissAlps.zip`)

## Antarctica
Download and read Antarctica topography data, as in [FourDAntarcticaSubglacialRouting.jl](https://github.com/mauro3/FourDAntarcticaSubglacialRouting.jl).
```
data = fetch_Antarctica([:bedmachine]; destination_dir)
```
So far only the :bedmachine is implemented.

## TODO
- make the reading functions for other Antarctica data work
- functions that help modifying raw data (e.g. smoothing), especially e.g. ice thickness
