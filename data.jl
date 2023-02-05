using CSV
using DataFrames

KABSdata = subset(CSV.read("Data/KABSdata.csv", DataFrame) , All().=>ByRow(!ismissing))
Rustripsdata = subset(CSV.read("Data/Rustripcabins2023.csv", DataFrame), All().=>ByRow(!ismissing))

N = size(Rustripsdata,1)

VectorsPerTrip  = Rustripsdata[:,"Vectors amount"]

TypesOfRustrips = unique(Rustripsdata[:,"Trip"])
FliptripIndex = 17 # Has to speak Danish



StudyLinesWithMoreVectorsOnSameTrip = ["General Engineering"]
GEvectors = size(subset(AllVectors, "Study line team" => a-> a .== "General Engineering"))[1]
Mixtrips = ["Mixtrip", "4-day Flip-trip", "Sober Mixtrip"]
nMixtrips = 4



# Read vectors

function ReadHiredVectors(path)
    subset(CSV.read(path, DataFrame), All() .=> ByRow(!ismissing), :"Want to hire" => a->a)
end


Vbyggetek = ReadHiredVectors("Data/Primary Distribution.xlsx - C. Byggeteknologi.csv")
Vbygdes = ReadHiredVectors("Data/Primary Distribution.xlsx - C. Byggeteknologi.csv")

# show(names(AllVectors)) # gives the following:
# ["Want to hire", "Name", "Has been vector before", "Wants Small Trip", "Wants Medium Tri", "Wants Large Trip", 
# ">21 og kørekort i min. 1 år", 
# "4-day Danish", "Weekend trip", "Campus trip", "3-day Sober", "Sober Mixtrip", "Mixtrip", "4-day Flip-trip", "One day Trips (Mixtrip)", 
# "Smoker", "Lives on Campus", "Ballerup vector", "Male", "Speaks Danish", "Access to Sowing Machine", "Power level", "Study line team"]

AllVectors = vcat(Vbyggetek,Vbygdes)

V = size(AllVectors, 1)
K = size(KABSdata,1)

Malevectors = size(subset(AllVectors, "Male" => a->a))[1]
MaleKABS = size(subset(KABSdata, "Male" => a->a.==1))[1]
AvgMaleRatio = (MaleKABS + Malevectors) / (V+K)


AvgSndTime = size(subset(AllVectors, "Has been vector before" => a->a))[1] / V
AvgDrivers = size(subset(AllVectors, ">21 og kørekort i min. 1 år" => a->a))[1] / V
AvgSmokers = size(subset(AllVectors, "Smoker" => a->a))[1] / V


ForbiddenStudylines = []
for n=1:N
    push!(ForbiddenStudylines, [])
    kabsstr = Rustripsdata[n,"KABS"]
    for kabs=eachsplit(kabsstr," og ")
        # println(kabs)
        studylines = KABSdata[occursin.(kabs,KABSdata."KABS name"),"Study line"]
        # Ugly julia code for looking up in the dataframe
        for sl = studylines
            for seperate_sl = collect(eachsplit(sl,","))
                push!(ForbiddenStudylines[n], seperate_sl)
            end
        end
    end
end
ForbiddenStudylines

