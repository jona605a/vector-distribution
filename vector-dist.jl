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
@variable(Prob, MoreMales[1:N]>=0)
@variable(Prob, MoreFemales[1:N]>=0)
@variable(Prob, FewerSew[1:N]>=0)
@variable(Prob, NoCampus[1:N]>=0)
@variable(Prob, AbsSndTime[1:N]>=0)
@variable(Prob, AbsDrivers[1:N]>=0)
@variable(Prob, AbsSmokers[1:N]>=0)
@variable(Prob, AbsPowerLevel[1:N]>=0)
@variable(Prob, AbsGEDeviation[1:N]>=0)
@variable(Prob, VectorUnSatisfiedwithTripSize[1:V,1:N], Bin)

# Helper variables
@variable(Prob, HasBallerupVector[1:N], Bin)
@variable(Prob, HasFemale[1:N], Bin)
@variable(Prob, HasMale[1:N], Bin)

@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V) <= VectorsPerTrip[n]) # Each trip gets the vectors it needs
@constraint(Prob, [v=1:V], sum(Assign[v,n] for n=1:N) == 1)                 # Each vector is assigned once

@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] <= Assign[v,n] - Assign[v2,n] + 1) # Define SameTeam
@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] >= Assign[v,n] - Assign[v2,n] - 1) # Define SameTeam

@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"]     for v=1:V) <= VectorsPerTrip[n]*AvgMaleRatio     + 1 + MoreMales[n])   # Define MoreMales
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) <= VectorsPerTrip[n]*(1-AvgMaleRatio) + 1 + MoreFemales[n]) # Define MoreFemales

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
DistributeEvenly(">20 og kørekort i min. 1 år", AbsDrivers)
# Distribute evenly the average power level
DistributeEvenly("Power level", AbsPowerLevel)

# If there are any Ballerup vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Ballerup"] for v=1:V) <= HasBallerupVector[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Ballerup"] for v=1:V) >= HasBallerupVector[n] * 2)

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

# ["Wants Small Trip", "Wants Medium Tri", "Wants Large Trip", 
# "Ok with English Trips", "Prefer English Trips", 
# "Ok with Sober English Trips", "Prefer Sober English Trips", 
# "Ok with 1-Day Trips", "Prefer 1-Day Trips", 
# "Ok with Weekend Trips", "Prefer Weekend Trips", 
# "Ok with Sober Weekend Trip", "Prefer Sober Weekend Trip", 
# "Ok with Campus Trip", "Prefer Campus Trip", 
# "Power level", "Study line team"]

# Small trip:  5-7 vectors
# Medium trip: 8-10 vectors
# Large trip:  11+ vectors

@constraint(Prob, [n=1:N,v=1:V], Assign[v,n] <= 
                                    AllVectors[v,"Wants Small Trip"] * (      Rustripsdata[n,"Vectors per trip"] <= 7 ) + 
                                    AllVectors[v,"Wants Medium Tri"] * (8 <=  Rustripsdata[n,"Vectors per trip"] <= 10) + 
                                    AllVectors[v,"Wants Large Trip"] * (11 <= Rustripsdata[n,"Vectors per trip"]      ) +
                                    VectorUnSatisfiedwithTripSize[v,n]    ) # Define VectorUnSatisfiedwithTripSize

# Distribute GE vectors evenly on mix trips
MixtripIndices = [1,2,3,4]
GEvectors = size(subset(AllVectors, "Study line team" => a-> a == "General Engineering"))[1]
@constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - GEvectors / length(MixtripIndices) <= AbsGEDeviation[n])
@constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,columnname] for v=1:V) - AvgValue) / length(MixtripIndices) <= AbsGEDeviation[n])

# @constraint(Prob, [n=1:N; ])

# ForbiddenRustripsPerStudyline = []
# for n=1:N
#     kabslist = Rustripsdata[n,""]

@objective(Prob,Max,
    - sum(MoreMales[n] for n=1:N)
    - sum(MoreFemales[n] for n=1:N)
    - sum(FewerSew[n] for n=1:N)
    - sum(NoCampus[n] for n=1:N)
    - sum(AbsSndTime[n] for n=1:N)
    - sum(AbsDrivers[n] for n=1:N)
    - sum(AbsSmokers[n] for n=1:N)
    - 100*sum(VectorUnSatisfiedwithTripSize[v,n] for v=1:V,n=1:N)
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


