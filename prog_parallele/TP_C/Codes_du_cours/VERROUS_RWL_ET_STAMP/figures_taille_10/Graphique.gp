if (!exists("titre")) titre = "Comparaison des performances de verrous"
if (!exists("xtitre")) xtitre = "Nombre de threads"
if (!exists("ytitre")) ytitre = "Temps de calcul (en ms.)"
if (!exists("mode_S")) mode_S = "donnees_S.dat"
if (!exists("mode_L")) mode_L = "donnees_L.dat"
if (!exists("mode_A")) mode_A = "donnees_A.dat"
if (!exists("mode_F")) mode_F = "donnees_F.dat"
if (!exists("mode_RWL")) mode_RWL = "donnees_RWL.dat"
if (!exists("mode_STAMP")) mode_STAMP = "donnees_STAMP.dat"

set title titre
set xlabel xtitre
set ylabel ytitre

# set xrange [1:16]
# set logscale y
# set yrange [0:100]

# set terminal  # Pour avoir la liste des "terminaux" disponibles

set xrange [1:20]
set yrange [0:30000]
set term svg
set out "RLW_vs_STAMP.svg"        # Je souhaite un graphique au format SVG
plot mode_S title "Verrou intrinseque" with lines,\
     mode_L title "Verrou Lock" with lines, \
     mode_RWL title "Verrou RWL" with lines,\
     mode_STAMP title "Verrou STAMP" with lines
#     mode_F title "Verrou equitable" with lines, \
#     mode_A title "Variable atomique" with lines, \

set term postscript
set yrange [0:28000]
set out "RLW_vs_STAMP.eps"        # Je le souhaite aussi au format EPS
plot mode_S title "Verrou intrinseque" with lines,\
     mode_L title "Verrou Lock" with lines, \
     mode_RWL title "Verrou RWL" with lines, \
     mode_STAMP title "Verrou STAMP" with lines
#     mode_F title "Verrou equitable" with lines, \
#     mode_A title "Variable atomique" with lines, \

set term pstricks              # Je le souhaite aussi au format LaTeX
set out "RLW_vs_STAMP.tex"
plot mode_S title "Verrou intrinseque" with lines,\
     mode_L title "Verrou Lock" with lines, \
     mode_RWL title "Verrou RWL" with lines,\
     mode_STAMP title "Verrou STAMP" with lines
#     mode_F title "Verrou equitable" with lines, \
#     mode_A title "Variable atomique" with lines, \

