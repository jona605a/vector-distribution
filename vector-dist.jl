#************************************************************************
#  assignment
using JuMP
using HiGHS
#************************************************************************
println("Defining variables...")
#************************************************************************
# Data

include("data.jl")

if sum(VectorsPerTrip) != V
    println("\n###################################################
             \nError, the number of vectors ($(V)) and required sum of vectors ($(sum(VectorsPerTrip))) do not match
             \n###################################################\n")
end


#************************************************************************
println("Defining model...")
Prob = Model(HiGHS.Optimizer)
set_time_limit_sec(Prob, 600.0)
#************************************************************************
# Model

@variable(Prob, Assign[1:V,1:N], Bin)
@variable(Prob, HasBuddyTeam[1:N,1:length(BuddyTeams)], Bin)
# @variable(Prob, SameTeam[1:V,1:V], Bin)

# Slack variables (should be penalized)
@variable(Prob, AbsGender[1:N]>=0)
@variable(Prob, FewerSew[1:N]>=0)
@variable(Prob, NoCampus[1:N]>=0)
@variable(Prob, AbsSndTime[1:N]>=0)
@variable(Prob, AbsDrivers[1:N]>=0)
@variable(Prob, AbsSmokers[1:N]>=0)
@variable(Prob, AbsPowerLevel[1:N]>=0)
# @variable(Prob, AbsGEDeviation[1:N]>=0)
@variable(Prob, VectorUnSatisfiedwithTripSize[1:V,1:N]>=0)

# Helper variables
@variable(Prob, HasBallerupVector[1:N], Bin)
@variable(Prob, HasLyngbyVector[1:N], Bin)
@variable(Prob, HasFemale[1:N], Bin)
@variable(Prob, HasMale[1:N], Bin)
@variable(Prob, GEmin>=0)
@variable(Prob, GEmax>=0)

@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V) == VectorsPerTrip[n]) # Each trip gets the vectors it needs
@constraint(Prob, [v=1:V], sum(Assign[v,n] for n=1:N) == 1)                 # Each vector is assigned once

# male vectors + male kabs <= AvgMaleRatio*(vectors+kabs) + AbsGender
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) + sum(KABSdata[occursin.(kabs,KABSdata."KABS name"),"Male"][1] for kabs=eachsplit(Rustripsdata[n,"KABS"]," og "))   <=  AvgMaleRatio  * (VectorsPerTrip[n] + length(collect(eachsplit(Rustripsdata[n,"KABS"], " og "))))    + AbsGender[n])   # Define AbsGender

@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Access to Sowing Machine"] for v=1:V) >= 2 - FewerSew[n]) # Define FewerSew
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Lives on Campus"] for v=1:V) >= 1 - NoCampus[n])          # Define NoCampus

function DistributeEvenly(columnname, variablename)
    AvgValue = size(subset(AllVectors, columnname => a->a))[1] / V
    @constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*VectorsPerTrip[n]  <= variablename[n])
    @constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue*VectorsPerTrip[n]) <= variablename[n])
end

# Distribute evenly the amount of 2nd time vectors
# Distribute evenly the amount of smokers
# Distribute evenly the amount of drivers
DistributeEvenly("Smoker", AbsSmokers)
DistributeEvenly("Has been vector before", AbsSndTime)
DistributeEvenly(">21 og kørekort i min. 1 år", AbsDrivers)

# Distribute evenly the average power level
AvgPow = sum(AllVectors[:,"Power level"]) / length(AllVectors[:,"Power level"])
@constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,"Power level"] for v=1:V) - AvgPow  <= AbsPowerLevel[n])
@constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,"Power level"] for v=1:V) - AvgPow) <= AbsPowerLevel[n])

# If there are any Ballerup vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Ballerup vector"] for v=1:V) <= HasBallerupVector[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Ballerup vector"] for v=1:V) >= HasBallerupVector[n] * 2)

# If there are any Lyngby vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(AllVectors[v,"Ballerup vector"] ? 0 : 1) for v=1:V) <= HasLyngbyVector[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(AllVectors[v,"Ballerup vector"] ? 0 : 1) for v=1:V) >= HasLyngbyVector[n] * 2)

# If there are any female vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) <= HasFemale[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) >= HasFemale[n] * 2)

# If there are any male vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) <= HasMale[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) >= HasMale[n] * 2)

# Small trip:  6-7 vectors
# Medium trip: 8-10 vectors
# Large trip:  11+ vectors

# @constraint(Prob, [n=1:N], sum(Assign[v,n] * (
#                                     AllVectors[v,"Wants Small Trip"] * (      Rustripsdata[n,"Vectors amount"] <= 7  ? 1 : 0) + 
#                                     AllVectors[v,"Wants Medium Tri"] * (8  <= Rustripsdata[n,"Vectors amount"] <= 10 ? 1 : 0) + 
#                                     AllVectors[v,"Wants Large Trip"] * (11 <= Rustripsdata[n,"Vectors amount"]       ? 1 : 0))  for v=1:V) <=
#                                     VectorsPerTrip[n] - VectorUnSatisfiedwithTripSize[n]    ) # Define VectorUnSatisfiedwithTripSize[n]
@constraint(Prob, [n=1:N,v=1:V], Assign[v,n] <= 
                                    AllVectors[v,"Wants Small Trip"] * (      Rustripsdata[n,"Vectors amount"] <= 7  ? 1 : 0) + 
                                    AllVectors[v,"Wants Medium Tri"] * (8 <=  Rustripsdata[n,"Vectors amount"] <= 10 ? 1 : 0) + 
                                    AllVectors[v,"Wants Large Trip"] * (11 <= Rustripsdata[n,"Vectors amount"]       ? 1 : 0  ) +
                                    VectorUnSatisfiedwithTripSize[v,n]    ) # Define VectorUnSatisfiedwithTripSize[v,n]

# Distribute GE vectors evenly on mix trips
# @constraint(Prob, [n=1:N; Rustripsdata[n,"Trip"] in Mixtrips],   sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="C. General Engineering" ? 1 : 0) for v=1:V) - GEvectors/nMixtrips  <= AbsGEDeviation[n])
# @constraint(Prob, [n=1:N; Rustripsdata[n,"Trip"] in Mixtrips], -(sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="C. General Engineering" ? 1 : 0) for v=1:V) - GEvectors/nMixtrips) <= AbsGEDeviation[n])

@constraint(Prob, [n=1:N; Rustripsdata[n,"Trip"] in Mixtrips], sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="C. General Engineering" ? 1 : 0) for v=1:V) <= GEmax)
@constraint(Prob, [n=1:N; Rustripsdata[n,"Trip"] in Mixtrips], sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="C. General Engineering" ? 1 : 0) for v=1:V) >= GEmin)

# At least 2 Ballerup vectors on the One-day trip
OnedayIndex = 1
@constraint(Prob, HasBallerupVector[OnedayIndex] == 1)

# Vectors on Danish trips must speak Danish
@constraint(Prob, [n=1:N;!(Rustripsdata[n,"Trip"] in Mixtrips)], sum(Assign[v,n]*AllVectors[v,"Speaks Danish"] for v=1:V) == VectorsPerTrip[n])
# Vectors on the Flip-trip must speak Danish
@constraint(Prob, sum(Assign[v,FliptripIndex]*AllVectors[v,"Speaks Danish"] for v=1:V) == VectorsPerTrip[FliptripIndex])

# A vector cannot be on a trip with their Study line KABS
@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V if (AllVectors[v,"Study line team"] in ForbiddenStudylines[n] && !(AllVectors[v,"Study line team"] in StudyLinesWithMoreVectorsOnSameTrip))) == 0)

# Buddy teams (if odd number of vectors, prefer 3 on one team than a lone 1 on another team)
@constraint(Prob, [n=1:N, k=1:length(BuddyTeams)], sum(Assign[v,n]*(AllVectors[v,"Study line team"]==sl ? 1 : 0) for v=1:V,sl=BuddyTeams[k]) >= HasBuddyTeam[n,k]*2)
@constraint(Prob, [n=1:N, k=1:length(BuddyTeams)], sum(Assign[v,n]*(AllVectors[v,"Study line team"]==sl ? 1 : 0) for v=1:V,sl=BuddyTeams[k]) <= HasBuddyTeam[n,k]*3)


@objective(Prob,Max,
    - 100*sum(VectorUnSatisfiedwithTripSize[v,n] for v=1:V,n=1:N)
    + sum(Assign[v,n]* (  (AllVectors[v,Rustripsdata[n,"Trip"]] == "No" ? -100 : 0)
                        + (AllVectors[v,Rustripsdata[n,"Trip"]] == "Ok" ? 0 : 0)
                        + (AllVectors[v,Rustripsdata[n,"Trip"]] == "Very yes" ? 20 : 0)
            ) for v=1:V,n=1:N)
    - 50*sum(AbsGender[n]*2 for n=1:N)
    - 50*sum(AbsSndTime[n] for n=1:N)
    - 30*sum(AbsDrivers[n] for n=1:N)
    - 30*sum(FewerSew[n] for n=1:N)
    - 30*sum(NoCampus[n] for n=1:N)
    - 10*sum(AbsSmokers[n] for n=1:N)
    # - 10*sum(AbsGEDeviation[n] for n=1:N)
    + 10*(GEmin-GEmax)
    + 1000*sum(HasBuddyTeam[n,k] for n=1:N,k=1:length(BuddyTeams)) # Maximize amount of buddy teams
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
#     println("  KABS: $(Rustripsdata[n,"KABS"])")
#     for v=1:V
#         if value(Assign[v,n]) > 0.5
#             println("    Vector nr $(v): $(AllVectors[v,"Name"])")
#         end
#     end
# end
#************************************************************************

println(round(sum(value(Assign[v,n])* (  (AllVectors[v,Rustripsdata[n,"Trip"]] == "Very yes" ? 1 : 0)) for v=1:V,n=1:N),digits=2), " vectors on a trip they preferred")
println(round(sum(value(Assign[v,n])* (  (AllVectors[v,Rustripsdata[n,"Trip"]] == "Ok" ? 1 : 0)) for v=1:V,n=1:N),digits=2), " vectors on a trip they were ok with")
println(round(sum(value(Assign[v,n])* (  (AllVectors[v,Rustripsdata[n,"Trip"]] == "No" ? 1 : 0)) for v=1:V,n=1:N),digits=2), " vectors on a trip they didn't want")
println(round(sum(value(VectorUnSatisfiedwithTripSize[v,n]) for v=1:V,n=1:N),digits=2), " vectors unsatisfied with trip size")
println(round(sum(value(AbsGender[n])*2 for n=1:N),digits=2), " gender deviation")
println(round(sum(value(AbsSndTime[n]) for n=1:N),digits=2), " second-time vector deviation")
println(round(sum(value(AbsDrivers[n]) for n=1:N),digits=2), " drivers deviation")
println(round(sum(value(FewerSew[n]) for n=1:N),digits=2), " crossteams with no sewing machines")
println(round(sum(value(NoCampus[n]) for n=1:N),digits=2), " crossteams with noone living on campus")
println(round(sum(value(AbsSmokers[n]) for n=1:N),digits=2), " smoker deviation")
# println(round(sum(value(AbsGEDeviation[n]) for n=1:N),digits=2), " GE deviation (on mix trips)")
println(round(sum(value(HasBuddyTeam[n,k]) for n=1:N,k=1:length(BuddyTeams)),digits=2), " total buddy teams")


XLSX.openxlsx("vector-output.xlsx", mode="w") do xf
    sheet = xf[1]
    XLSX.rename!(sheet, "new_sheet")

    sheet["A1"] = collect(["Vector" "Study line team" "Has been vector before" "Wants the trip type"])

    curRow = 2
    for n=1:N
        sheet[curRow, 1] = [Rustripsdata[n,"KABS"] Rustripsdata[n,"Cabin"] Rustripsdata[n,"Trip"]]
        curRow += 1
        for v=1:V
            if value(Assign[v,n]) > 0.5
                # println([AllVectors[v,"Name"] AllVectors[v,"Study line team"] AllVectors[v,"Has been vector before"] AllVectors[v,Rustripsdata[n,"Trip"]]])
                sheet[curRow,1] = [AllVectors[v,"Name"] AllVectors[v,"Study line team"] AllVectors[v,"Has been vector before"] AllVectors[v,Rustripsdata[n,"Trip"]]]
                curRow += 1
            end
        end
        curRow += 1
    end
end

