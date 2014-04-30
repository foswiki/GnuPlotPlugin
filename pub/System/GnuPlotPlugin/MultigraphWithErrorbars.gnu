set title "Multigraph with error bars"
set xlabel "X Axis Label"
set ylabel "Y Axis Label"
set style data lp
plot [.8:4.2] \
  "%ATTACHDIR%/MultigraphWithErrorbarsData.data" using 1:2 t "Curve Title", \
  "%ATTACHDIR%/MultigraphWithErrorbarsData.data" using 1:2:3:4 notitle with errorbars ps 0, \
  "%ATTACHDIR%/MultigraphWithErrorbarsData.data" using 1:5 t "Other Curve", \
  "%ATTACHDIR%/MultigraphWithErrorbarsData.data" using 1:5:6:7 notitle with errorbars ps 0
