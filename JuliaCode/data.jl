using CSV
using DataFrames

Rustrips = [
    "Campus1"               
    "Campus2"
    "Egegården (week)"
    "Egegården2"
    "Farmen1"
    "Farmen2"
    "Fønsborg1"
    "Fønsborg2"
    "Hylkedam1"
    "Hylkedam2"
    "Højbjerg1"
    "Højbjerg2"
    "Ingeborg1"
    "Ingeborg2"
    "Klinteborg1"
    "Klinteborg2"
    "Klintehytten (week)"
    "Klintehytten2 (Mix Trip)"
    "Lyngborgen2"
    "Lyngbyborg2"
    "OneDay"
    "Pedersborghytten (Sober weekend)"
    "Pedersborghytten2"
    "Port Arthur1"
    "Port Arthur2 (Mix Trip)"
    "Sejerborg1"
    "Sejerborg2"
    "Skovbrynet1"
    "Skovbrynet2"
]

N = length(Rustrips)

KABSNames = [
    "Rasmus Holm Høyrup"
    "Oliver Springborg"
    "Liv Didi"
    "Otto Westy Rasmussen"
    "Emil Nymark Trangeled"
    "Silas Lasak Hedeboe"
    "Xandra Huryn"
    "Ida Cecilie Hoielt"
    "Oliver Koch"
    "Mike Linde"
    "Jacob Hagen Pedersen"
    "Adar Alan Benli"
    "Nick Sommer"
    "Henrik Gjerding Hynkemejer"
    "William Sommer"
    "Pernille Diana Vinding Jönsson"
    "Emil Hovgaard Wrona Olsen"
    "Signe Staun"
    "Rasmus Sigurd Sundin"
    "Jonathan Schmidt Højlev"
    "Annemarie Louw-Pedersen"
    "Jonas Matthiesen"
    "Alan Yang"
    "August Weijers"
    "Monica Diaz Hansen"
    "Jonas Bøttzauw Pedersen"
    "Pernille Christie"
    "Jean-Victor Leif Joseph Bendixen-Fernex de Mongex"
    "Tobias Lopez Sejersen Christensen"
    "Michail Philip Harmandjiev (Mimo)"
    "Isabella Hochstenbach Fink-Jensen"
]

KABSpertrip = [1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]

# 0 for Danish, 1 for English
RustripLanguage = [0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
# 0 for Alcohol, 1 for non-Alcohol
RustripAlcohol = [0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

VectorsPerTrip = [7, 7, 9, 6, 6, 7, 8, 7, 7, 7, 8, 9, 9, 7, 7, 15, 15, 9, 9, 8, 7, 6, 7, 8, 9, 9, 16, 16, 13]


df = CSV.read("/home/jonathan/Documents/Uniarbejde/KABS22/vector-distribution/Primary Distribution.xlsx - C. Byggeteknologi.csv", DataFrame)
V = 258
Femaleratio = 0.37



