using CSV
using DataFrames
using XLSX

KABSdata = subset(CSV.read("Data/KABSdata.csv", DataFrame) , All().=>ByRow(!ismissing))
Rustripsdata = subset(CSV.read("Data/Rustripcabins2023.csv", DataFrame), All().=>ByRow(!ismissing))
STUDYLINES = ["C. Cyberteknologi","C. Elektroteknologi", "C. General Engineering", "C. Medicin og Teknologi", "C. Kemi & Teknologi", "D. SUIT", "D. Fødevaresikkerhed og -kvalitet", "C. Bygningsdesign", "C. Kunstig Intelligens og Data", "C. Produktion og Konstruktion", "C. Bæredygtigt Energidesign", "D. Eksport og Teknologi", "C. Softwareteknologi", "D. Elektrisk Energiteknologi","D. Elektroteknologi", "D. Byggeri og Infrastruktur", "D. Process og Innovation", "C. Byggeteknologi", "C. Matematik og Teknologi", "D. Produktion","D. Transport og Mobilitet", "C. Miljøteknologi", "D. Maskinteknik", "C. Life Science og Teknologi", "D. Kemi- og Bioteknik","D. Kemiteknik og International Business", "C. Data Science og Management", "C. Computer Engineering", "C. Geofysik og Rumteknologi", "D. Softwareteknologi", "D. Arktisk Byggeri og Infrastruktur","D. Fiskeriteknologi","C. Teknologi", "C. Design og Innovation", "D. Byggeri og Infrastruktur", "D. IT og Økonomi", "C. Fysik og Nanoteknologi", "D. Bygningsdesign"]
S = length(STUDYLINES)
N = size(Rustripsdata,1)

VectorsPerTrip  = Rustripsdata[:,"Vectors amount"]

TypesOfRustrips = unique(Rustripsdata[:,"Trip"])
FliptripIndex = 17 # Has to speak Danish
OnedayIndex = 1 # Has to have Ballerup vectors

StudyLinesWithMoreVectorsOnSameTrip = ["General Engineering"]
Mixtrips = ["Mixtrip", "4-day Flip-trip", "Sober Mixtrip", "One day Trips (Mixtrip)"]
nMixtrips = 5

########### Read vectors ###########

primdist = XLSX.readxlsx("Data/Primary Distribution.xlsx")
# show(XLSX.sheetnames(primdist)) # gives the following:
sheetnames = ["C. Byggeteknologi", "C. Bygningsdesign", "C. Bæredygtigt Energidesign", "C. Cyberteknologi", "C. Computer Engineering", "C. Data Science og Management", "C. Design og Innovation", "C. Elektroteknologi", "C. Kemi og Teknologi", "C. Fysik og Nanoteknologi", "C. General Engineering", "C. Geofysik og Rumteknologi", "C. Kunstig Intelligens og Data", "C. Life Science og Teknologi", "C. Matematik og Teknologi", "C. Medicin og Teknologi", "C. Miljøteknologi", "C. Produktion og Konstruktion", "C. Softwareteknologi", "C. Teknologi", "D. Arktisk Byggeri og Infrastru", "D. Byggeri og Infrastruktur", "D. Bygningsdesign", "D. Eksport og Teknologi", "D. Elektrisk Energiteknologi", "D. Elektroteknologi", "D. Fiskeriteknologi", "D. Fødevaresikkerhed og -kvalit", "D. IT og Økonomi", "D. IT-elektronik", "D. Kemi- og Bioteknik", "D. Kemiteknik og International ", "D. Maskinteknik", "D. Process og Innovation", "D. Produktion", "D. Softwareteknologi", "D. Sundhedsteknologi", "D. Mobilitet, Transport og Logi"]

testing = false

function ReadHiredVectors(studyline)
    print("Reading sheet: ",studyline)
    vectorsheet = DataFrame(XLSX.gettable(primdist[studyline]))
    # print("\tsize: ",size(vectorsheet,1))
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
    println("\t",size(vectorsheet,1))
    return vectorsheet
end

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

if testing
    if sum(VectorsPerTrip) < size(AllVectors, 1)
        AllVectors = AllVectors[1:sum(VectorsPerTrip),:] # If testing, cut off all vectors in excess
    end
end

K = size(KABSdata,1)
V = size(AllVectors, 1)

#### Done reading ####

GEvectors = size(subset(AllVectors, "Study line team" => a-> a .== "C. General Engineering"))[1]
Malevectors = size(subset(AllVectors, "Male" => a->a))[1]
MaleKABS = size(subset(KABSdata, "Male" => a->a.==1))[1]
AvgMaleRatio = (MaleKABS + Malevectors) / (V+K)


AvgSndTime = size(subset(AllVectors, "Has been vector before" => a->a))[1] / V
AvgDrivers = size(subset(AllVectors, ">21 og kørekort i min. 1 år" => a->a))[1] / V
AvgSmokers = size(subset(AllVectors, "Smoker" => a->a))[1] / V

TrustKABS = ["Thor" "Malou"] # Can't have each others' russes on their cross team

StudylineteamsWithMeetingsTogether = [["C. Cyberteknologi","C. Elektroteknologi","C. Bæredygtigt Energidesign", "C. Computer Engineering"], # SNE
                                      ["C. Fysik og Nanoteknologi","C. Geofysik og Rumteknologi"], # NSA
                                      ["C. Softwareteknologi","C. Matematik og Teknologi","C. Kunstig Intelligens og Data"], # SMKID
                                      ["D. Process og Innovation","D. Produktion","D. Transport og Mobilitet", "C. Eksport og Teknologi"], # PROMO
                                      ["D. Kemi- og Bioteknik","D. Kemiteknik og International Business","D. Fødevaresikkerhed og -kvalitet"], # BØF
                                      ["D. Softwareteknologi","D. IT og Økonomi"], # d. soft + d.itø
                                      ["C. Bygningsdesign","D. Bygningsdesign"], # BygDes
                                      ]

BuddyTeams = [["C. Fysik og Nanoteknologi","C. Geofysik og Rumteknologi"], # NSA
              ["C. Softwareteknologi","C. Matematik og Teknologi","C. Kunstig Intelligens og Data"], # SMKID
              ["D. Process og Innovation","D. Produktion","D. Transport og Mobilitet"], # PROMO
              ["C. Bygningsdesign","D. Bygningsdesign"], # BygDes
              ]

ForbiddenStudylines = Vector{String}[]
for n=1:N
    push!(ForbiddenStudylines, [])
    kabsstr = Rustripsdata[n,"KABS"]
    for kabs=eachsplit(kabsstr," og ")
        print(kabs,"\t")
        studylines = KABSdata[occursin.(kabs,KABSdata."KABS name"),"Study line"]
        println(studylines)
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


