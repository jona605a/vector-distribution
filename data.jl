using CSV
using DataFrames

StudylineKABS = CSV.read("Data/KABSdata.csv", DataFrame)
Rustripsdata = CSV.read("Data/Rustripsdata.csv", DataFrame)

N = size(Rustripsdata,1)

# RustripName     = Rustripsdata[:,1]
# RustripLanguage = Rustripsdata[:,2]
# RustripWeekend  = Rustripsdata[:,3]
# RustripAlcohol  = Rustripsdata[:,4]
# VectorsPerTrip  = Rustripsdata[:,5]
# KABSforTrip     = Rustripsdata[:,6]



# Read vectors

function ReadHiredVectors(path)
    subset(CSV.read(path, DataFrame), All() .=> ByRow(!ismissing), :"Want to hire" => a->a)
end


Vbyggetek = ReadHiredVectors("Data/Primary Distribution.xlsx - C. Byggeteknologi.csv")
Vbygdes = ReadHiredVectors("Data/Primary Distribution.xlsx - C. Bygningsdesing.csv")

# show(names(AllVectors)) # gives the following:
# ["Want to hire", "Name", "Has been vector before", "Wants Small Trip", "Wants Medium Tri", "Wants Large Trip", 
# ">20 og kørekort i min. 1 år", "Ok with English Trips", "Prefer English Trips", "Ok with Sober English Trips", 
# "Prefer Sober English Trips", "Ok with 1-Day Trips", "Prefer 1-Day Trips", "Ok with Weekend Trips", "Prefer Weekend Trips", 
# "Ok with Sober Weekend Trip", "Prefer Sober Weekend Trip", "Ok with Campus Trip", "Prefer Campus Trip", "Smoker", "Lives on Campus", 
# "Sex", "Access to Sowing Machine", "Power level", "Study line team", "Lyngby/Ballerup"]

AllVectors = vcat(Vbyggetek,Vbygdes)
AllVectors = transform(AllVectors, :"Sex" => ByRow(x -> x=="M") => :"Male")
AllVectors = transform(AllVectors, :"Lyngby/Ballerup" => ByRow(x -> x=="B") => :"Ballerup")

# AllVectors = transform(AllVectors, :"Study line team" => ByRow(x -> x) => :"ForbiddenTrips")

# collect(eachsplit(StudylineKABS[findfirst(y->y=="D. Produktion", StudylineKABS[:,1]) , 2],","))

V = size(AllVectors, 1)

AvgMaleRatio = size(subset(AllVectors, :"Male" => a->a))[1] / V
AvgSndTime = size(subset(AllVectors, :"Has been vector before" => a->a))[1] / V
AvgDrivers = size(subset(AllVectors, :">20 og kørekort i min. 1 år" => a->a))[1] / V
AvgSmokers = size(subset(AllVectors, :"Smoker" => a->a))[1] / V

StudyLinesWithMoreVectorsOnSameTrip = ["General Engineering"]

