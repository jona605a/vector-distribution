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

# Helper variables
@variable(Prob, MoreSndTime[1:N]>=0)
@variable(Prob, LessSndTime[1:N]>=0)
@variable(Prob, MoreDrivers[1:N]>=0)
@variable(Prob, LessDrivers[1:N]>=0)
@variable(Prob, MoreSmokers[1:N]>=0)
@variable(Prob, LessSmokers[1:N]>=0)
@variable(Prob, HasBallerupVector[1:N], Bin)

@objective(Prob,Max,
    - sum(MoreMales[n] for n=1:N)
    - sum(MoreFemales[n] for n=1:N)
    - sum(FewerSew[n] for n=1:N)
    - sum(NoCampus[n] for n=1:N)
    - sum(AbsSndTime[n] for n=1:N)
    - sum(AbsDrivers[n] for n=1:N)
    - sum(AbsSmokers[n] for n=1:N)
)

@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V) <= VectorsPerTrip[n]) # Each trip gets the vectors it needs
@constraint(Prob, [v=1:V], sum(Assign[v,n] for n=1:N) == 1)                 # Each vector is assigned once

@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] <= Assign[v,n] - Assign[v2,n] + 1) # Define SameTeam
@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] >= Assign[v,n] - Assign[v2,n] - 1) # Define SameTeam

@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Male"]     for v=1:V) <= VectorsPerTrip[n]*(1-Femaleratio) + 1 + MoreMales[n])   # Define MoreMales
@constraint(Prob, [n=1:N], sum(Assign[v,n]*(1-AllVectors[v,"Male"]) for v=1:V) <= VectorsPerTrip[n]*Femaleratio     + 1 + MoreFemales[n]) # Define MoreFemales

@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Access to Sowing Machine"] for v=1:V) >= 2 - FewerSew[n]) # Define FewerSew
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Lives on Campus"] for v=1:V) >= 1 - NoCampus[n])          # Define NoCampus

# Distribute evenly the amount of 2nd time vectors
@constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,"Has been vector before"] for v=1:V) - AvgSndTime  <= MoreSndTime[n])
@constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,"Has been vector before"] for v=1:V) - AvgSndTime) <= LessSndTime[n])
@constraint(Prob, [n=1:N], AbsSndTime[n] >= MoreSndTime[n] + LessSndTime[n])

# Distribute evenly the amount of drivers
@constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,">20 og kørekort i min. 1 år"] for v=1:V) - AvgDrivers  <= MoreDrivers[n])
@constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,">20 og kørekort i min. 1 år"] for v=1:V) - AvgDrivers) <= LessDrivers[n])
@constraint(Prob, [n=1:N], AbsDrivers[n] >= MoreDrivers[n] + LessDrivers[n])

# Distribute evenly the amount of smokers
@constraint(Prob, [n=1:N],   sum(Assign[v,n]*AllVectors[v,"Smoker"] for v=1:V) - AvgSmokers  <= MoreSmokers[n])
@constraint(Prob, [n=1:N], -(sum(Assign[v,n]*AllVectors[v,"Smoker"] for v=1:V) - AvgSmokers) <= LessSmokers[n])
@constraint(Prob, [n=1:N], AbsSmokers[n] >= MoreSmokers[n] + LessSmokers[n])

# If there are any Ballerup vectors, there has to be at least 2
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Ballerup"] for v=1:V) <= HasBallerupVector[n] * VectorsPerTrip[n])
@constraint(Prob, [n=1:N], sum(Assign[v,n]*AllVectors[v,"Ballerup"] for v=1:V) >= HasBallerupVector[n] * 2)

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
else
    println("No optimal solution available")
end
#************************************************************************


