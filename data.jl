using CSV
using DataFrames
using XLSX

KABSdata = subset(CSV.read("Data/KABSdata.csv", DataFrame) , All().=>ByRow(!ismissing))
Rustripsdata = subset(CSV.read("Data/Rustripcabins2023.csv", DataFrame), All().=>ByRow(!ismissing))

N = size(Rustripsdata,1)

VectorsPerTrip  = Rustripsdata[:,"Vectors amount"]

TypesOfRustrips = unique(Rustripsdata[:,"Trip"])
FliptripIndex = 17 # Has to speak Danish



StudyLinesWithMoreVectorsOnSameTrip = ["General Engineering"]
Mixtrips = ["Mixtrip", "4-day Flip-trip", "Sober Mixtrip", "One day Trips (Mixtrip)"]
nMixtrips = 5



########### Read vectors ###########


sheetnames = ["C. Bygningsdesing", "C. Bæredygtigt Energidesing", "C. Data Science og Management", "C. Design og Innovation", "C. Elektroteknologi samt C. Cyb", "C. Fysik og Nanoteknologi", "C. General Engineering", "C. Geofysik og Rumteknologi", "C. Kemi & Teknologi", "C. Kunstig Intelligens og Data", "C. Life Science og Teknologi", "C. Matematik og Teknologi", "C. Medicin og Teknologi", "C. Produktion og Konstruktion", "C. Softwareteknologi", "C. Vand, bioressourcer og miljø", "D. Byggeri og Infrastruktur sam", "D. Bygningsdesign", "D. Eksport og Teknologi", "D. Elektroteknologi samt D. Ele", "D. Fødevaresikkerhed og -kvalit", "D. IT og Økonomi", "D. Kemi og Bioteknik samt D. Ke", "D. Maskinteknik", "D. Softwareteknologi", "D. Process og Innovation, Produ", "D. Sundhedsteknologi samt D. IT"]

primdist = XLSX.readxlsx("Data/Primary Distribution.xlsx")
testing = true

function ReadHiredVectors(studyline)
    # println("Reading sheet: ",studyline)
    vectorsheet = DataFrame(XLSX.gettable(primdist[studyline]))
    #vectorsheet = DataFrame(XLSX.readtable("Data/Primary Distribution.xlsx", studyline))
    vectorsheet = subset(vectorsheet, All() .=> ByRow(!ismissing), :"Want to hire" => a->a, skipmissing=true)
    if testing
        vectorsheet = transform(vectorsheet, ["Ok with English Trips", "Prefer English Trips"] => ByRow((ok, pref) -> (pref ? "Very yes" : (ok ? "Ok" : "No"))) => "Mixtrip")
        vectorsheet = transform(vectorsheet, ["Ok with English Trips", "Prefer English Trips"] => ByRow((ok, pref) -> (pref ? "Very yes" : (ok ? "Ok" : "No"))) => "4-day Flip-trip")
        vectorsheet = transform(vectorsheet, ["Ok with Sober English Trips", "Prefer Sober English Trips"] => ByRow((ok, pref) -> (pref ? "Very yes" : (ok ? "Ok" : "No"))) => "Sober Mixtrip")
        vectorsheet = transform(vectorsheet, ["Ok with Weekend Trips", "Prefer Weekend Trips"] => ByRow((ok, pref) -> (pref ? "Very yes" : (ok ? "Ok" : "No"))) => "Weekend trip")
        vectorsheet = transform(vectorsheet, ["Ok with 1-Day Trips", "Prefer 1-Day Trips"] => ByRow((ok, pref) -> (pref ? "Very yes" : (ok ? "Ok" : "No"))) => "One day Trips (Mixtrip)")
        vectorsheet = transform(vectorsheet, ["Ok with Campus Trip", "Prefer Campus Trip"] => ByRow((ok, pref) -> (pref ? "Very yes" : (ok ? "Ok" : "No"))) => "Campus trip")
        vectorsheet = transform(vectorsheet, ["Ok with Sober Weekend Trip", "Prefer Sober Weekend Trip"] => ByRow((ok, pref) -> (pref ? "Very yes" : (ok ? "Ok" : "No"))) => "3-day Sober")
        vectorsheet = transform(vectorsheet, ["Ok with English Trips", "Prefer English Trips"] => ByRow((ok, pref) -> ("Very yes")) => "4-day Danish")
        vectorsheet = transform(vectorsheet, ["Ok with English Trips", "Prefer English Trips"] => ByRow((ok, pref) -> true) => "Speaks Danish")
        vectorsheet = transform(vectorsheet, "Lyngby/Ballerup" => ByRow(a->a == "L" ? false : true) => "Ballerup vector")
        vectorsheet = transform(vectorsheet, "Sex" => ByRow(a->a == "M" ? true : false) => "Male")
        vectorsheet = transform(vectorsheet, ">20 og kørekort i min. 1 år" => ">21 og kørekort i min. 1 år")
    end
    vectorsheet = transform(vectorsheet, "Power level" => ByRow(x->(typeof(x)==String ? parse(Float64,replace(x,","=>".")) : x)) => "Power level")
    
    return vectorsheet
end

#map(x->(typeof(x)==String ? parse(Float64,replace(x,","=>".")) : x), AllVectors[:,"Power level"])

# old:
# ["Want to hire", "Name", "Has been vector before", "Wants Small Trip", "Wants Medium Tri", "Wants Large Trip", 
# ">20 og kørekort i min. 1 år", 
# "Ok with English Trips", "Prefer English Trips", => Mixtrip
# "Ok with Sober English Trips", "Prefer Sober English Trips", => Sober Mixtrip
# "Ok with 1-Day Trips", "Prefer 1-Day Trips", One day Trips (Mixtrip)
# "Ok with Weekend Trips", "Prefer Weekend Trips", Weekend trip
# "Ok with Sober Weekend Trip", "Prefer Sober Weekend Trip", 3-day Sober
# "Ok with Campus Trip", "Prefer Campus Trip", Campus trip
# "Smoker", "Lives on Campus", "Sex", "Access to Sowing Machine", "Power level", "Study line team", "Lyngby/Ballerup"]

# new:
# show(names(AllVectors)) # gives the following:
# ["Want to hire", "Name", "Has been vector before", "Wants Small Trip", "Wants Medium Tri", "Wants Large Trip", 
# ">21 og kørekort i min. 1 år", 
# "4-day Danish", "Weekend trip", "Campus trip", "3-day Sober", "Sober Mixtrip", "Mixtrip", "4-day Flip-trip", "One day Trips (Mixtrip)", 
# "Smoker", "Lives on Campus", "Ballerup vector", "Male", "Speaks Danish", "Access to Sowing Machine", "Power level", "Study line team"]

global AllVectors = ReadHiredVectors(sheetnames[1])
for sheetname = sheetnames[2:end]
    vsheet = ReadHiredVectors(sheetname)
    global AllVectors = vcat(AllVectors,vsheet)
end

V = size(AllVectors, 1)
K = size(KABSdata,1)

if testing
    if sum(VectorsPerTrip) < V
        AllVectors = AllVectors[1:sum(VectorsPerTrip),:]
    end
end

V = size(AllVectors, 1)
# Done reading

GEvectors = size(subset(AllVectors, "Study line team" => a-> a .== "C. General Engineering"))[1]
Malevectors = size(subset(AllVectors, "Male" => a->a))[1]
MaleKABS = size(subset(KABSdata, "Male" => a->a.==1))[1]
AvgMaleRatio = (MaleKABS + Malevectors) / (V+K)


AvgSndTime = size(subset(AllVectors, "Has been vector before" => a->a))[1] / V
AvgDrivers = size(subset(AllVectors, ">21 og kørekort i min. 1 år" => a->a))[1] / V
AvgSmokers = size(subset(AllVectors, "Smoker" => a->a))[1] / V

StudylineteamsWithMeetingsTogether = [["C. Cyberteknologi","C. Elektroteknologi","C. Bæredygtigt Energidesign"], # SNE
                                      ["C. Fysik og Nanoteknologi","C. Geofysik og Rumteknologi"], # NSA
                                      ["C. Softwareteknologi","C. Matematik og Teknologi","C. Kunstig Intelligens og Data"], # SMKID
                                      ["D. Process og Innovation","D. Produktion","D. Transport og Mobilitet"], # PROMO
                                      ["D. Kemi- og Bioteknik","D. Kemiteknik og International Business","D. Fødevaresikkerhed og -kvalitet"], # BØF
                                      ["D. Softwareteknologi","D. IT og Økonomi"], # d. soft + d.itø
                                      ["C. Bygningsdesign","D. Bygningsdesign"], # bygdes
                                      ]

BuddyTeams = [["C. Fysik og Nanoteknologi","C. Geofysik og Rumteknologi"], # NSA
              ["C. Softwareteknologi","C. Matematik og Teknologi","C. Kunstig Intelligens og Data"], # SMKID
              ["D. Process og Innovation","D. Produktion","D. Transport og Mobilitet"], # PROMO
              ["C. Bygningsdesign","D. Bygningsdesign"], # bygdes
              ]

ForbiddenStudylines = Vector{String}[]
for n=1:N
    push!(ForbiddenStudylines, [])
    kabsstr = Rustripsdata[n,"KABS"]
    for kabs=eachsplit(kabsstr," og ")
        studylines = KABSdata[occursin.(kabs,KABSdata."KABS name"),"Study line"]
        for sl = eachsplit(studylines[1],",")
            if any([sl in a for a in StudylineteamsWithMeetingsTogether])
                for sll = StudylineteamsWithMeetingsTogether[[sl in a for a in StudylineteamsWithMeetingsTogether]][1]
                    push!(ForbiddenStudylines[n], sll)
                end
            else
                push!(ForbiddenStudylines[n], sl)
            end
        end
    end
end
# ForbiddenStudylines


