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
    println("Error, the number of vectors $(V) and required sum of vectors $(sum(VectorsPerTrip)) do not match")
end


#************************************************************************
println("Defining model...")
#************************************************************************
# Model

@variable(Prob, Assign[1:V,1:N], Bin)
@variable(Prob, SameTeam[1:V,1:V], Bin)
# Slack variables
@variable(Prob, MoreMales[1:T]>=0)
@variable(Prob, MoreFemales[1:T]>=0)
@variable(Prob, FewerSew[1:N]>=0)


@constraint(Prob, [n=1:N], sum(Assign[v,n] for v=1:V) == VectorsPerTrip[n]) # Each trip gets the right number of vectors 
@constraint(Prob, [v=1:N], sum(Assign[v,n] for n=1:N) == 1) # Each vector is assigned at most once

@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] <= Assign[v,n] - Assign[v2,n] + 1) # Define SameTable
@constraint(Prob, [n=1:N,v=1:V,v2=1:V], SameTeam[v,v2] >= Assign[v,n] - Assign[v2,n] - 1) # Define SameTable

@constraint(Prob, [n=1:N], sum(Assign[v,n]*Male[v]   for v=1:V) <= VectorsPerTrip[n]*(1-Femaleratio) + 1 + MoreMales[n])    # Define MoreMales
@constraint(Prob, [n=1:N], sum(Assign[v,n]*Female[v] for v=1:V) <= VectorsPerTrip[n]*Femaleratio     + 1 + MoreFemales[n])  # Define MoreFemales

@constraint(Prob, [n=1:N], sum(Assign[v,n]*SewingMachine[v] for v=1:V) >= 1 - FewerSew[n])    # Define FewerSew




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


