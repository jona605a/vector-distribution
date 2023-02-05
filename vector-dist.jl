#************************************************************************
#  assignment
using JuMP
using HiGHS
Prob = Model(HiGHS.Optimizer)
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
#************************************************************************
# Model

@variable(Prob, Assign[1:V,1:N], Bin)
@variable(Prob, SameTeam[1:V,1:V], Bin)

# Slack variables (should be penalized)
@variable(Prob, AbsGender[1:N]>=0)
@variable(Prob, FewerSew[1:N]>=0)
@variable(Prob, NoCampus[1:N]>=0)
@variable(Prob, AbsSndTime[1:N]>=0)
@variable(Prob, AbsDrivers[1:N]>=0)
@variable(Prob, AbsSmokers[1:N]>=0)
@variable(Prob, AbsPowerLevel[1:N]>=0)
@variable(Prob, AbsGEDeviation[1:N]>=0)
@variable(Prob, VectorUnSatisfiedwithTripSize[1:V,1:N]>=0)

# Helper variables
@variable(Prob, HasBallerupVector[1:N], Bin)
@variable(Prob, HasFemale[1:N], Bin)
@variable(Prob, HasMale[1:N], Bin)

@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V) <= VectorsPerTrip[n]) # Each trip gets the vectors it needs
@constraint(Prob, [v=1:V], sum(Assign[v,n] for n=1:N) == 1)                 # Each vector is assigned once

@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] <= Assign[v,n] - Assign[v2,n] + 1) # Define SameTeam
@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] >= Assign[v,n] - Assign[v2,n] - 1) # Define SameTeam

# male vectors + male kabs <= AvgMaleRatio*(vectors+kabs) + AbsGender
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) + sum(KABSdata[occursin.(kabs,KABSdata."KABS name"),"Male"][1] for kabs=eachsplit(Rustripsdata[n,"KABS"]," og "))   <=  AvgMaleRatio  * (VectorsPerTrip[n] + length(collect(eachsplit(Rustripsdata[n,"KABS"], " og "))))    + AbsGender[n])   # Define AbsGender

@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Access to Sowing Machine"] for v=1:V) >= 2 - FewerSew[n]) # Define FewerSew
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Lives on Campus"] for v=1:V) >= 1 - NoCampus[n])          # Define NoCampus

function DistributeEvenly(columnname, variablename)
    AvgValue = size(subset(AllVectors, columnname => a->a))[1] / V
    @constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue  <= variablename[n])
    @constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue) <= variablename[n])
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

# If there are any female vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) <= HasFemale[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) >= HasFemale[n] * 2)

# If there are any male vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) <= HasMale[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"] for v=1:V) >= HasMale[n] * 2)

# show(names(Vbygdes)) # gives the following:
# ["Want to hire", "Name", "Has been vector before", "Wants Small Trip", "Wants Medium Tri", "Wants Large Trip", 
# ">20 og kørekort i min. 1 år", "Ok with English Trips", "Prefer English Trips", "Ok with Sober English Trips", 
# "Prefer Sober English Trips", "Ok with 1-Day Trips", "Prefer 1-Day Trips", "Ok with Weekend Trips", "Prefer Weekend Trips", 
# "Ok with Sober Weekend Trip", "Prefer Sober Weekend Trip", "Ok with Campus Trip", "Prefer Campus Trip", "Smoker", "Lives on Campus", 
# "Sex", "Access to Sowing Machine", "Power level", "Study line team", "Lyngby/Ballerup"]

# ["Ok with English Trips", "Prefer English Trips", 
# "Ok with Sober English Trips", "Prefer Sober English Trips", 
# "Ok with 1-Day Trips", "Prefer 1-Day Trips", 
# "Ok with Weekend Trips", "Prefer Weekend Trips", 
# "Ok with Sober Weekend Trip", "Prefer Sober Weekend Trip", 
# "Ok with Campus Trip", "Prefer Campus Trip"]

# Small trip:  6-7 vectors
# Medium trip: 8-10 vectors
# Large trip:  11+ vectors

# @constraint(Prob, [n=1:N], sum(Assign[v,n] * (
#                                     AllVectors[v,"Wants Small Trip"] * (      Rustripsdata[n,"Vectors amount"] <= 7  ? 1 : 0) + 
#                                     AllVectors[v,"Wants Medium Tri"] * (8  <= Rustripsdata[n,"Vectors amount"] <= 10 ? 1 : 0) + 
#                                     AllVectors[v,"Wants Large Trip"] * (11 <= Rustripsdata[n,"Vectors amount"]       ? 1 : 0))  for v=1:V) <=
#                                     VectorsPerTrip[n] - VectorUnSatisfiedwithTripSize[n]    ) # Define VectorUnSatisfiedwithTripSize
@constraint(Prob, [n=1:N,v=1:V], Assign[v,n] <= 
                                    AllVectors[v,"Wants Small Trip"] * (      Rustripsdata[n,"Vectors amount"] <= 7  ? 1 : 0) + 
                                    AllVectors[v,"Wants Medium Tri"] * (8 <=  Rustripsdata[n,"Vectors amount"] <= 10 ? 1 : 0) + 
                                    AllVectors[v,"Wants Large Trip"] * (11 <= Rustripsdata[n,"Vectors amount"]       ? 1 : 0  ) +
                                    VectorUnSatisfiedwithTripSize[v,n]    ) # Define VectorUnSatisfiedwithTripSize

# Distribute GE vectors evenly on mix trips
@constraint(Prob, [n=1:N; Rustripsdata[n,"Trip"] in Mixtrips],   sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="General Engineering" ? 1 : 0) for v=1:V) - GEvectors/nMixtrips  <= AbsGEDeviation[n])
@constraint(Prob, [n=1:N; Rustripsdata[n,"Trip"] in Mixtrips], -(sum(Assign[v,n]*(AllVectors[v,"Study line team"]=="General Engineering" ? 1 : 0) for v=1:V) - GEvectors/nMixtrips) <= AbsGEDeviation[n])

# Vectors on the Flip-trip must speak Danish
if false
    @constraint(Prob, sum(Assign[v,FliptripIndex]*AllVectors[v,"Speaks Danish"] for v=1:V) == VectorsPerTrip[FliptripIndex])
end
# A vector cannot be on a trip with their Study line KABS
@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V if (AllVectors[v,"Study line team"] in ForbiddenStudylines[n] && !(AllVectors[v,"Study line team"] in StudyLinesWithMoreVectorsOnSameTrip))) == 0)



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
    - 10*sum(AbsGEDeviation[n] for n=1:N)
)


#************************************************************************
println("Solving...")
#************************************************************************
# Solve
solution = optimize!(Prob)
println("Termination status: $(termination_status(Prob))")
#************************************************************************

#************************************************************************
if termination_status(Prob) == MOI.OPTIMAL
    println("\nOptimal objective value: $(objective_value(Prob))")
    for n=1:N
        # println("AbsDrivers[$(n)] = $(value(AbsDrivers[n]))")
    end
else
    println("No optimal solution available")
end
#************************************************************************


