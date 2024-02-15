#************************************************************************
#  assignment
using JuMP
using HiGHS
#************************************************************************
println("Defining variables...")
#************************************************************************
# Data

include("data.jl")



#************************************************************************
println("Defining model...")
Prob = Model(HiGHS.Optimizer)
set_time_limit_sec(Prob, 240.0)
#************************************************************************
# Model

@variable(Prob, Assign[1:V,1:N], Bin)
@variable(Prob, HasBuddyTeam[1:N,1:length(BuddyTeams)], Bin)

# Slack variables (should be penalized)
@variable(Prob, LynAbsAssign[1:LT]>=0)
@variable(Prob, LynAbsGender[1:LT]>=0)
@variable(Prob, LynAbsSndTime[1:LT]>=0)
@variable(Prob, LynAbsDrivers[1:LT]>=0)
@variable(Prob, LynAbsSmokers[1:LT]>=0)
@variable(Prob, LynAbsEnergyScore[1:LT]>=0)

@variable(Prob, BalAbsAssign[1:BT]>=0)
@variable(Prob, BalAbsGender[1:BT]>=0)
@variable(Prob, BalAbsSndTime[1:BT]>=0)
@variable(Prob, BalAbsDrivers[1:BT]>=0)
@variable(Prob, BalAbsSmokers[1:BT]>=0)
@variable(Prob, BalAbsEnergyScore[1:BT]>=0)

@variable(Prob, FewerSew[1:N]>=0)
@variable(Prob, NoCampus[1:N]>=0)
#@variable(Prob, VectorUnSatisfiedwithTripSize[1:V,1:N]>=0)
@variable(Prob, HasVectorFromStudyLine[1:N,1:S],Bin)
@variable(Prob, TooMany[1:N]>=0)

# Helper variables
#@variable(Prob, HasBallerupVector[1:N], Bin)
#@variable(Prob, HasLyngbyVector[1:N], Bin)
@variable(Prob, HasFemale[1:N], Bin)
@variable(Prob, HasMale[1:N], Bin)
@variable(Prob, GEmin>=0)
@variable(Prob, GEmax>=0)
@variable(Prob, Lynmax>=0)
@variable(Prob, Lynmin>=0)
@variable(Prob, Balmax>=0)
@variable(Prob, Balmin>=0)


###### Hard constraints ######

for v=1:V
    for n=1:N 
        if AllVectors[v,"Ballerup vector"] != (TRIPdata[n,"Type"] == "Balleruptur")
            # Vectors can't be on trips on another campus
            fix(Assign[v,n], 0; force = true)
        end
    end
end


#@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V) == VectorsPerTrip[n]) # Each trip gets the vectors it needs
@constraint(Prob, [v=1:V], sum(Assign[v,n] for n=1:N) == 1)                 # Each vector is assigned once
@constraint(Prob, [n=1:BT],      sum(Assign[v,n] for v=1:V) - B/BT  <= BalAbsAssign[n])
@constraint(Prob, [n=1:BT],    -(sum(Assign[v,n] for v=1:V) - B/BT) <= BalAbsAssign[n])
@constraint(Prob, [n=(BT+1):N],   sum(Assign[v,n] for v=1:V) - L/LT  <= LynAbsAssign[n-BT])
@constraint(Prob, [n=(BT+1):N], -(sum(Assign[v,n] for v=1:V) - L/LT) <= LynAbsAssign[n-BT])

@constraint(Prob, [n=1:BT], sum(Assign[v,n] for v=1:V) >= Balmin)
@constraint(Prob, [n=1:BT], sum(Assign[v,n] for v=1:V) <= Balmax)
@constraint(Prob, [n=(BT+1):LT], sum(Assign[v,n] for v=1:V) <= Lynmin)
@constraint(Prob, [n=(BT+1):LT], sum(Assign[v,n] for v=1:V) <= Lynmax)

# Vectors on Danish trips and the Flip-trip must speak Danish
#@constraint(Prob, [n=1:N;!(TRIPdata[n,"Trip"] in Mixtrips)], sum(Assign[v,n]*AllVectors[v,"Speaks Danish"] for v=1:V) == VectorsPerTrip[n])
#@constraint(Prob, sum(Assign[v,FliptripIndex]*AllVectors[v,"Speaks Danish"] for v=1:V) == VectorsPerTrip[FliptripIndex])

# A vector cannot be on a trip with their Study line KABS
@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V if (AllVectors[v,"Study line team"] in ForbiddenStudylines[n] && !(AllVectors[v,"Study line team"] in StudyLinesWithMoreVectorsOnSameTrip) && !AllVectors[v,"Ballerup vector"])) == 0)

# No more than 1 vector from a study line on each trip (on lyngby trips)
@constraint(Prob, [n=1:N,s=1:S; TRIPdata[n,"Type"] != "Balleruptur" && STUDYLINES[s]!="C. General Engineering"], sum(Assign[v,n] for v=1:V if AllVectors[v,"Study line team"]==STUDYLINES[s]) <= HasVectorFromStudyLine[n,s]+TooMany[n])

# TrustKABS can't have each others' vectors
@constraint(Prob, [k=1:2], sum(Assign[v,findfirst(occursin.(TrustKABS[k],TRIPdata."CollectedKABS"))] * 
                    (AllVectors[v,"Study line team"] in collect(eachsplit(KABSdata[occursin.(TrustKABS[3-k],KABSdata."KABS navn"),"Studieretning"][1],",")) ? 1 : 0) # "if they study the other TrustKABS' line"
                    for v=1:V) == 0)

# If there are any female   vectors, there has to be at least 2
# If there are any male     vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) <= HasFemale[n] * 1000)
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) >= HasFemale[n] * 2)

@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) <= HasMale[n] * 1000)
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) >= HasMale[n] * 2)


###### Soft constraints ######

# Buddy teams (if odd number of vectors, prefer 3 on one team than a lone 1 on another team)
@constraint(Prob, [n=1:N, k=1:length(BuddyTeams)], sum(Assign[v,n]*(AllVectors[v,"Study line team"]==sl ? 1 : 0) for v=1:V,sl=BuddyTeams[k]) >= HasBuddyTeam[n,k]*2)
@constraint(Prob, [n=1:N, k=1:length(BuddyTeams)], sum(Assign[v,n]*(AllVectors[v,"Study line team"]==sl ? 1 : 0) for v=1:V,sl=BuddyTeams[k]) <= HasBuddyTeam[n,k]*3)

# Even gender distribution
# male vectors + male kabs <= AvgMaleRatio*(vectors+kabs) + AbsGender
@constraint(Prob, [n=1:BT],     sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) + sum(KABSdata[occursin.(kabs,KABSdata."KABS navn"),"Male"][1] for kabs=eachsplit(TRIPdata[n,"CollectedKABS"]," og "))   <=  AvgMaleBalRatio  * (sum(Assign[v,n] for v=1:V) + TRIPdata[n,"NKABS"])    + BalAbsGender[n])   # Define AbsGender
@constraint(Prob, [n=(BT+1):N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) + sum(KABSdata[occursin.(kabs,KABSdata."KABS navn"),"Male"][1] for kabs=eachsplit(TRIPdata[n,"CollectedKABS"]," og "))   <=  AvgMaleLynRatio  * (sum(Assign[v,n] for v=1:V) + TRIPdata[n,"NKABS"])    + LynAbsGender[n-BT])   # Define AbsGender

# Each team should have 2 people with sewing machines
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Access to Sowing Machine"] for v=1:V) >= 2 - FewerSew[n])

# Each team should have at least one vector living on campus
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Lives on Campus"] for v=1:V) >= 1 - NoCampus[n])


function DistributeEvenly(columnname, variablename)
    AvgValue = size(subset(AllVectors, columnname => a->a))[1] / V
    @constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*sum(Assign[v,n] for v=1:V)  <= variablename[n])
    @constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*sum(Assign[v,n] for v=1:V)) <= variablename[n])
end

function DistributeEvenlyBal(columnname, variablename)
    AvgValue = size(subset(subset(AllVectors, columnname => a->a), "Ballerup vector" => a -> a))[1] / B
    @constraint(Prob, [n=1:BT],   sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*sum(Assign[v,n] for v=1:V)  <= variablename[n])
    @constraint(Prob, [n=1:BT], -(sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*sum(Assign[v,n] for v=1:V)) <= variablename[n])
end

function DistributeEvenlyLyn(columnname, variablename)
    AvgValue = (size(subset(AllVectors, columnname => a->a))[1] - size(subset(subset(AllVectors, columnname => a->a), "Ballerup vector" => a -> a))[1]) / L
    @constraint(Prob, [n=(BT+1):N],   sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*sum(Assign[v,n] for v=1:V)  <= variablename[n-BT])
    @constraint(Prob, [n=(BT+1):N], -(sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*sum(Assign[v,n] for v=1:V)) <= variablename[n-BT])
end

# Distribute evenly the amount of 2nd time vectors
# Distribute evenly the amount of smokers
# Distribute evenly the amount of drivers
DistributeEvenlyBal("Smoker", BalAbsSmokers)
DistributeEvenlyBal("Has been vector before", BalAbsSndTime)
DistributeEvenlyBal(">21 og kørekort i min. 1 år", BalAbsDrivers)
DistributeEvenlyLyn("Smoker", LynAbsSmokers)
DistributeEvenlyLyn("Has been vector before", LynAbsSndTime)
DistributeEvenlyLyn(">21 og kørekort i min. 1 år", LynAbsDrivers)

# Distribute evenly the average Energy score
TotEnergy = sum(AllVectors[:,"Energy score"])
BalEnergy = sum(Balvectors[:,"Energy score"])
LynEnergy = TotEnergy - BalEnergy
BalAvgEne = BalEnergy / B
LynAvgEne = LynEnergy / L

@constraint(Prob, [n=1:BT]    ,   sum(Assign[v,n]*AllVectors[v,"Energy score"] for v=1:V) - BalAvgEne  <= BalAbsEnergyScore[n])
@constraint(Prob, [n=1:BT]    , -(sum(Assign[v,n]*AllVectors[v,"Energy score"] for v=1:V) - BalAvgEne) <= BalAbsEnergyScore[n])
@constraint(Prob, [n=(BT+1):N],   sum(Assign[v,n]*AllVectors[v,"Energy score"] for v=1:V) - LynAvgEne  <= LynAbsEnergyScore[n-BT])
@constraint(Prob, [n=(BT+1):N], -(sum(Assign[v,n]*AllVectors[v,"Energy score"] for v=1:V) - LynAvgEne) <= LynAbsEnergyScore[n-BT])


# Distribute GE vectors evenly on mix trips
@constraint(Prob, [n=1:N; TRIPdata[n,"Type"] in Mixtrips], sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="C. General Engineering" ? 1 : 0) for v=1:V) <= GEmax)
@constraint(Prob, [n=1:N; TRIPdata[n,"Type"] in Mixtrips], sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="C. General Engineering" ? 1 : 0) for v=1:V) >= GEmin)


###### Objective ######

@objective(Prob,Max,
    - 50*sum(BalAbsGender[n]*2 for n=1:BT)
    + sum(Assign[v,n]* (  (AllVectors[v,TRIPdata[n,"Type"] == "Mixtrip (Lyngby)" ? "Engelsk tur" : "Dansk tur"] == "Helst ikke" ? -100 : 0)
                    + (AllVectors[v,TRIPdata[n,"Type"] == "Mixtrip (Lyngby)" ? "Engelsk tur" : "Dansk tur"] == "Ok" ? 0 : 0)
                    + (AllVectors[v,TRIPdata[n,"Type"] == "Mixtrip (Lyngby)" ? "Engelsk tur" : "Dansk tur"] == "Meget gerne" ? 20 : 0)
        ) for v=1:V,n=1:N)
    - 50*sum(BalAbsSndTime[n] for n=1:BT)
    - 30*sum(BalAbsDrivers[n] for n=1:BT)
    - 10*sum(BalAbsSmokers[n] for n=1:BT)
    - 50*sum(LynAbsGender[n]*2 for n=1:LT)
    - 50*sum(LynAbsSndTime[n] for n=1:LT)
    - 30*sum(LynAbsDrivers[n] for n=1:LT)
    - 10*sum(LynAbsSmokers[n] for n=1:LT)
    - 30*sum(FewerSew[n] for n=1:N)
    - 30*sum(NoCampus[n] for n=1:N)
    # - 10*(GEmax-GEmin)                  # Minimize GE difference on the mixtrips
    # - 10*(Balmax-Balmin)
    # - 10*(Lynmax-Lynmin)
    - 50*sum(BalAbsAssign[n] for n=1:BT)
    - 50*sum(LynAbsAssign[n] for n=1:LT)
    + 1000*sum(HasBuddyTeam[n,k] for n=1:N,k=1:length(BuddyTeams)) # Maximize amount of buddy teams
    - sum(BalAbsEnergyScore[n] for n=1:BT)
    - sum(LynAbsEnergyScore[n] for n=1:LT)
    - 1000*sum(TooMany)
)


#************************************************************************
println("Solving...")
#************************************************************************
# Solve
solution = optimize!(Prob)
println("Termination status: $(termination_status(Prob))")
#************************************************************************

#************************************************************************
println("No optimal solution available")
println("\nFinal objective value: $(objective_value(Prob))")
# println("\n####### Printing each trip: #######\n")
# for n=1:N
#     println("  KABS: $(TRIPdata[n,"KABS"])")
#     for v=1:V
#         if value(Assign[v,n]) > 0.5
#             println("    Vector nr $(v): $(AllVectors[v,"Name"])")
#         end
#     end
# end
#************************************************************************

println(round(sum(value(BalAbsGender[n])*2 for n=1:BT),digits=2), " Bal gender deviation")
println(round(sum(value(BalAbsSndTime[n]) for n=1:BT),digits=2), " Bal second-time vector deviation")
println(round(sum(value(BalAbsDrivers[n]) for n=1:BT),digits=2), " Bal drivers deviation")
println(round(sum(value(BalAbsSmokers[n]) for n=1:BT),digits=2), " Bal smoker deviation")
println(round(sum(value(LynAbsGender[n])*2 for n=1:LT),digits=2), " Lyn gender deviation")
println(round(sum(value(LynAbsSndTime[n]) for n=1:LT),digits=2), " Lyn second-time vector deviation")
println(round(sum(value(LynAbsDrivers[n]) for n=1:LT),digits=2), " Lyn drivers deviation")
println(round(sum(value(LynAbsSmokers[n]) for n=1:LT),digits=2), " Lyn smoker deviation")
println(round(sum(value(FewerSew[n]) for n=1:N),digits=2), " crossteams with fewer than 2 sewing machines")
println(round(sum(value(NoCampus[n]) for n=1:N),digits=2), " crossteams with noone living on campus")
println(round(sum(value(HasBuddyTeam[n,k]) for n=1:N,k=1:length(BuddyTeams)),digits=2), " total buddy teams")


XLSX.openxlsx("vector-output.xlsx", mode="w") do xf
    sheet = xf[1]
    XLSX.rename!(sheet, "new_sheet")

    sheet["A1"] = collect(["Vector" "Study line team" "Has been vector before"])

    curRow = 2
    for n=1:N
        sheet[curRow, 1] = [TRIPdata[n,"CollectedKABS"] TRIPdata[n,"Type"] "" "Vectors" sum(value(Assign[v,n]) for v=1:V) "Energy score" sum(value(Assign[v,n])*AllVectors[v,"Energy score"] for v=1:V)/sum(value(Assign[v,n]) for v=1:V)]
        curRow += 1
        for v=1:V
            if value(Assign[v,n]) > 0.5
                # println([AllVectors[v,"Name"] AllVectors[v,"Study line team"] AllVectors[v,"Has been vector before"] AllVectors[v,TRIPdata[n,"Trip"]]])
                sheet[curRow,1] = [AllVectors[v,"Name"] AllVectors[v,"Study line team"] AllVectors[v,"Has been vector before"]]
                curRow += 1
            end
        end
        curRow += 1
    end
end
